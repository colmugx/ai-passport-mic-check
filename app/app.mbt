///|
/// Meter response controls how quickly the displayed level falls after a peak.
enum ResponseMode {
  Fast
  Medium
  Slow
}

///|
fn response_label(mode : ResponseMode) -> String {
  match mode {
    Fast => "FAST"
    Medium => "MEDIUM"
    Slow => "SLOW"
  }
}

///|
fn next_response(mode : ResponseMode) -> ResponseMode {
  match mode {
    Fast => Medium
    Medium => Slow
    Slow => Fast
  }
}

///|
/// Converts a signed PCM16 sample to a non-negative magnitude.
/// `-32768` needs a special case because its positive value is 32768.
fn pcm16_magnitude(sample : Int) -> Int {
  if sample == -32768 {
    32768
  } else if sample < 0 {
    -sample
  } else {
    sample
  }
}

///|
/// Integer approximation of amplitude dBFS.
///
/// It first normalizes the amplitude by powers of two (about 6 dB per octave),
/// then uses 1 dB thresholds inside the final octave. Values below -60 dBFS
/// are intentionally floored to -60 because the UI does not need a wider
/// range.
fn amplitude_dbfs(amplitude : Int) -> Int {
  if amplitude <= 0 {
    return -60
  }
  if amplitude >= 32767 {
    return 0
  }

  let mut normalized = amplitude
  let mut db = 0
  while normalized < 16384 && db > -60 {
    normalized = normalized * 2
    db -= 6
  }

  let residual = if normalized >= 29205 {
    0
  } else if normalized >= 26029 {
    -1
  } else if normalized >= 23198 {
    -2
  } else if normalized >= 20675 {
    -3
  } else if normalized >= 18427 {
    -4
  } else if normalized >= 16423 {
    -5
  } else {
    -6
  }

  (db + residual).max(-60)
}

///|
/// Converts accumulated PCM16 energy into RMS dBFS without floating point.
/// The binary search computes floor(sqrt(mean_square)) in the PCM amplitude
/// domain, then reuses the dBFS approximation above.
fn rms_dbfs(sum_squares : Int64, sample_count : Int) -> Int {
  if sample_count <= 0 || sum_squares <= 0L {
    return -60
  }
  let mean_square = sum_squares / sample_count.to_int64()
  let mut low = 0
  let mut high = 32769
  while low + 1 < high {
    let mid = (low + high) / 2
    let square = mid.to_int64() * mid.to_int64()
    if square <= mean_square {
      low = mid
    } else {
      high = mid
    }
  }
  amplitude_dbfs(low)
}

///|
fn signal_label(dbfs : Int) -> String {
  if dbfs <= -45 {
    "VERY LOW"
  } else if dbfs <= -30 {
    "LOW"
  } else if dbfs <= -6 {
    "GOOD"
  } else {
    "HOT"
  }
}

///|
/// Portable MIC CHECK application.
///
/// Capture is started only by a semantic button event. This matters on Web,
/// where microphone permission can be asynchronous and user-gesture-gated.
pub struct App {
  priv canvas : @graphics.Canvas
  priv samples : FixedArray[Int]
  priv mut wants_capture : Bool
  priv mut capture_status : @audio.CaptureStatus
  priv mut frozen : Bool
  priv mut response : ResponseMode
  priv mut level_cdb : Int
  priv mut peak_hold_dbfs : Int
  priv mut dropped_samples : Int
  priv mut dropped_offset : Int
  priv mut last_now_us : Int64?
}

///|
pub fn App::new() -> App {
  {
    canvas: @graphics.Canvas::for_display(),
    samples: FixedArray::make(256, 0),
    wants_capture: false,
    capture_status: @audio.capture_status(),
    frozen: false,
    response: Medium,
    level_cdb: -6000,
    peak_hold_dbfs: -60,
    dropped_samples: 0,
    dropped_offset: 0,
    last_now_us: None,
  }
}

///|
fn App::start_capture(self : App) -> Unit {
  self.frozen = false
  self.level_cdb = -6000
  self.peak_hold_dbfs = -60
  self.capture_status = @audio.capture_start()
  self.wants_capture = match self.capture_status {
    Requesting => true
    Recording => true
    _ => false
  }
  self.dropped_samples = @audio.capture_dropped_samples()
  self.dropped_offset = self.dropped_samples
}

///|
fn App::stop_capture(self : App) -> Unit {
  if self.wants_capture || self.capture_status == Recording ||
    self.capture_status == Requesting {
    @audio.capture_stop()
  }
  self.wants_capture = false
  self.capture_status = @audio.capture_status()
  self.frozen = false
}

///|
fn App::toggle_capture(self : App) -> Unit {
  if self.wants_capture || self.capture_status == Recording ||
    self.capture_status == Requesting {
    self.stop_capture()
  } else {
    self.start_capture()
  }
}

///|
fn App::reset_holds(self : App) -> Unit {
  self.peak_hold_dbfs = -60
  self.dropped_offset = self.dropped_samples
}

///|
fn App::reset_all(self : App) -> Unit {
  self.stop_capture()
  self.response = Medium
  self.level_cdb = -6000
  self.peak_hold_dbfs = -60
  self.dropped_samples = 0
  self.dropped_offset = 0
  self.last_now_us = None
}

///|
fn response_fall_cdb_per_second(mode : ResponseMode) -> Int {
  match mode {
    Fast => 2400
    Medium => 1200
    Slow => 600
  }
}

///|
/// Applies attack immediately and a time-based release so host frame rate does
/// not change the meter feel.
fn App::integrate_level(
  self : App,
  instant_dbfs : Int,
  delta_us : Int64,
) -> Unit {
  let instant_cdb = instant_dbfs * 100
  if instant_cdb >= self.level_cdb {
    self.level_cdb = instant_cdb
  } else if delta_us > 0L {
    let fall_rate = response_fall_cdb_per_second(self.response)
    let fall = (
      delta_us * fall_rate.to_int64() / 1_000_000L
    ).to_int()
    self.level_cdb = (self.level_cdb - fall).max(instant_cdb).max(-6000)
  }
}

///|
fn App::poll_capture(
  self : App,
  delta_us : Int64,
  update_meter : Bool,
) -> Unit {
  let mut overall_peak = 0
  let mut sum_squares = 0L
  let mut sample_count = 0

  // Up to four 256-sample reads form an approximately 64 ms RMS window at
  // 16 kHz. The main meter therefore reflects sustained input energy instead
  // of a single mechanical click or one-sample spike.
  for _ in 0..<4 {
    let count = @audio.capture_read(self.samples)
    if count == 0 {
      break
    }
    for i in 0..<count {
      let magnitude = pcm16_magnitude(self.samples[i])
      let wide = magnitude.to_int64()
      sum_squares += wide * wide
      sample_count += 1
      if magnitude > overall_peak {
        overall_peak = magnitude
      }
    }
  }

  if update_meter {
    let instant = rms_dbfs(sum_squares, sample_count)
    self.integrate_level(instant, delta_us)
    let peak = amplitude_dbfs(overall_peak)
    if peak > self.peak_hold_dbfs {
      self.peak_hold_dbfs = peak
    }
    self.dropped_samples = @audio.capture_dropped_samples()
  }
}

///|
/// Advances microphone state from the Host's monotonic frame clock.
pub fn App::advance(self : App, now_us : Int64) -> Unit {
  let delta_us = match self.last_now_us {
    Some(previous) => {
      if now_us > previous { now_us - previous } else { 0L }
    }
    None => 0L
  }
  self.last_now_us = Some(now_us)

  self.capture_status = @audio.capture_status()

  match self.capture_status {
    Recording => {
      self.wants_capture = true
      // Freeze affects only the displayed meter. Continue draining Host PCM so
      // the diagnostic itself never causes capture-ring overflow.
      self.poll_capture(delta_us, !self.frozen)
    }
    Requesting => self.wants_capture = true
    Idle => {
      if self.wants_capture {
        // A Host may transition back to Idle after capture has been stopped
        // externally. Reflect that state instead of pretending capture runs.
        self.wants_capture = false
      }
    }
    Unavailable => self.wants_capture = false
    Denied => self.wants_capture = false
    Failed => self.wants_capture = false
  }
}

///|
/// Semantic input behavior. Gesture recognition remains a Host responsibility.
pub fn App::handle_button_event(
  self : App,
  button : @input.Button,
  event : @input.ButtonEvent,
) -> Unit {
  match event {
    Click =>
      match button {
        Ok => self.toggle_capture()
        Up => self.response = next_response(self.response)
        Down => self.reset_holds()
      }
    DoubleClick =>
      if button == Ok && self.capture_status == Recording {
        self.frozen = !self.frozen
      }
    LongPress =>
      if button == Ok {
        self.reset_all()
      }
    Press => ()
  }
}

///|
fn App::display_dbfs(self : App) -> Int {
  if self.level_cdb >= 0 {
    0
  } else {
    // Round negative centi-dB toward the nearest whole displayed dB.
    ((self.level_cdb - 50) / 100).max(-60)
  }
}

///|
fn App::visible_dropped_samples(self : App) -> Int {
  (self.dropped_samples - self.dropped_offset).max(0)
}

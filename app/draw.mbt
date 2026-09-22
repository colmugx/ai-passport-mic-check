///|
fn color_bg() -> @core.Color {
  @core.Color::rgb(r=9, g=14, b=24)
}

///|
fn color_panel() -> @core.Color {
  @core.Color::rgb(r=24, g=34, b=51)
}

///|
fn color_text() -> @core.Color {
  @core.Color::rgb(r=226, g=234, b=242)
}

///|
fn color_muted() -> @core.Color {
  @core.Color::rgb(r=124, g=145, b=166)
}

///|
fn color_low() -> @core.Color {
  @core.Color::rgb(r=65, g=151, b=231)
}

///|
fn color_good() -> @core.Color {
  @core.Color::rgb(r=45, g=199, b=111)
}

///|
fn color_hot() -> @core.Color {
  @core.Color::rgb(r=244, g=104, b=74)
}

///|
fn color_peak() -> @core.Color {
  @core.Color::rgb(r=250, g=210, b=80)
}

///|
fn level_color(dbfs : Int) -> @core.Color {
  if dbfs <= -30 {
    color_low()
  } else if dbfs <= -6 {
    color_good()
  } else {
    color_hot()
  }
}

///|
fn db_to_meter_x(dbfs : Int, x : Int, width : Int) -> Int {
  let clamped = dbfs.max(-60).min(0)
  x + (clamped + 60) * width / 60
}

///|
/// Draw one seven-segment numeral at 26x46 pixels.
fn draw_digit(
  canvas : @graphics.Canvas,
  digit : Int,
  x : Int,
  y : Int,
  color : @core.Color,
) -> Unit {
  let a = digit != 1 && digit != 4
  let b = digit != 5 && digit != 6
  let c = digit != 2
  let d = digit != 1 && digit != 4 && digit != 7
  let e = digit == 0 || digit == 2 || digit == 6 || digit == 8
  let f = digit != 1 && digit != 2 && digit != 3 && digit != 7
  let g = digit != 0 && digit != 1 && digit != 7

  if a {
    canvas.fill_rect(x=x + 4, y~, w=18, h=4, color~)
  }
  if b {
    canvas.fill_rect(x=x + 22, y=y + 4, w=4, h=18, color~)
  }
  if c {
    canvas.fill_rect(x=x + 22, y=y + 25, w=4, h=18, color~)
  }
  if d {
    canvas.fill_rect(x=x + 4, y=y + 43, w=18, h=4, color~)
  }
  if e {
    canvas.fill_rect(x~, y=y + 25, w=4, h=18, color~)
  }
  if f {
    canvas.fill_rect(x~, y=y + 4, w=4, h=18, color~)
  }
  if g {
    canvas.fill_rect(x=x + 4, y=y + 21, w=18, h=4, color~)
  }
}

///|
fn draw_big_dbfs(
  canvas : @graphics.Canvas,
  dbfs : Int,
  y : Int,
  color : @core.Color,
) -> Unit {
  let magnitude = (-dbfs).max(0).min(99)
  let tens = magnitude / 10
  let ones = magnitude % 10
  let start_x = 72
  if dbfs < 0 {
    canvas.fill_rect(x=start_x, y=y + 21, w=18, h=4, color~)
  }
  draw_digit(canvas, tens, start_x + 30, y, color)
  draw_digit(canvas, ones, start_x + 62, y, color)
  canvas.text(text="DBFS", x=start_x + 96, y=y + 34, color=color_muted())
}

///|
fn draw_header(canvas : @graphics.Canvas, battery_percent : Int?) -> Unit {
  canvas.text(text="MIC CHECK", x=14, y=12, color=color_text())
  let battery = match battery_percent {
    Some(value) => "BAT \{value.max(0).min(100)}%"
    None => "BAT --%"
  }
  let bx = canvas.width() - @graphics.text_width(text=battery) - 14
  canvas.text(text=battery, x=bx, y=12, color=color_muted())
  canvas.line(x0=14, y0=24, x1=canvas.width() - 14, y1=24, color=color_panel())
}

///|
fn capture_message(app : App) -> String {
  match app.capture_status {
    Unavailable => "NO MIC"
    Idle => "PRESS OK"
    Requesting => "ALLOW MIC"
    Recording =>
      if app.frozen {
        "FROZEN"
      } else {
        signal_label(app.display_dbfs())
      }
    Denied => "MIC DENIED"
    Failed => "MIC FAILED"
  }
}

///|
fn App::draw_meter(self : App) -> Unit {
  let x = 20
  let y = 112
  let width = self.canvas.width() - 40
  let height = 24
  let dbfs = self.display_dbfs()

  self.canvas.fill_rect(x~, y~, w=width, h=height, color=color_panel())

  let fill_width = (db_to_meter_x(dbfs, x, width) - x).max(0)
  self.canvas.fill_rect(x~, y~, w=fill_width, h=height, color=level_color(dbfs))

  let low_good = db_to_meter_x(-30, x, width)
  let good_hot = db_to_meter_x(-6, x, width)
  self.canvas.line(
    x0=low_good,
    y0=y - 4,
    x1=low_good,
    y1=y + height + 4,
    color=color_muted(),
  )
  self.canvas.line(
    x0=good_hot,
    y0=y - 4,
    x1=good_hot,
    y1=y + height + 4,
    color=color_muted(),
  )

  let peak_x = db_to_meter_x(self.peak_hold_dbfs, x, width)
  self.canvas.fill_rect(
    x=peak_x - 1,
    y=y - 3,
    w=3,
    h=height + 6,
    color=color_peak(),
  )

  self.canvas.text(text="-60", x~, y=y + 31, color=color_muted())
  self.canvas.text(text="-30", x=low_good - 7, y=y + 31, color=color_muted())
  self.canvas.text(text="-6", x=good_hot - 4, y=y + 31, color=color_muted())
  self.canvas.text(text="0", x=x + width - 4, y=y + 31, color=color_muted())
}

///|
fn App::draw_status_panel(self : App) -> Unit {
  let y = 166
  let width = self.canvas.width() - 28
  self.canvas.fill_rect(x=14, y~, w=width, h=70, color=color_panel())

  let message = capture_message(self)
  self.canvas.text(
    text=message,
    x=24,
    y=y + 12,
    color=level_color(self.display_dbfs()),
  )
  self.canvas.text(
    text="PEAK \{self.peak_hold_dbfs} DBFS",
    x=24,
    y=y + 29,
    color=color_text(),
  )
  self.canvas.text(
    text="RESP \{response_label(self.response)}",
    x=24,
    y=y + 42,
    color=color_text(),
  )
  self.canvas.text(
    text="DROP \{self.visible_dropped_samples()}",
    x=24,
    y=y + 55,
    color=if self.visible_dropped_samples() > 0 {
      color_hot()
    } else {
      color_muted()
    },
  )
}

///|
fn App::draw_controls(self : App) -> Unit {
  let y = self.canvas.height() - 62
  let action = if self.wants_capture ||
    self.capture_status == Recording ||
    self.capture_status == Requesting {
    "OK STOP"
  } else {
    "OK START"
  }

  self.canvas.text(text="UP RESPONSE", x=14, y~, color=color_muted())
  self.canvas.text(text="DOWN RESET", x=14, y=y + 12, color=color_muted())
  self.canvas.text(text=action, x=14, y=y + 24, color=color_text())
  self.canvas.text(text="2X OK FREEZE", x=14, y=y + 36, color=color_muted())
  self.canvas.text(text="HOLD OK CLEAR", x=14, y=y + 48, color=color_muted())
}

///|
/// Rendering is read-only with respect to capture and meter state.
pub fn App::draw(self : App, battery_percent : Int?) -> Unit {
  self.canvas.clear(color=color_bg())
  draw_header(self.canvas, battery_percent)
  draw_big_dbfs(
    self.canvas,
    self.display_dbfs(),
    42,
    level_color(self.display_dbfs()),
  )
  self.draw_meter()
  self.draw_status_panel()
  self.draw_controls()
}

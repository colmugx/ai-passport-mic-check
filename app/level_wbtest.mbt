///|
test "PCM16 magnitude handles the signed minimum" {
  inspect(pcm16_magnitude(-32768), content="32768")
  inspect(pcm16_magnitude(-1234), content="1234")
  inspect(pcm16_magnitude(1234), content="1234")
}

///|
test "amplitude dBFS approximation has useful anchors" {
  inspect(amplitude_dbfs(32767), content="0")
  inspect(amplitude_dbfs(29205), content="-1")
  inspect(amplitude_dbfs(23198), content="-3")
  inspect(amplitude_dbfs(16384), content="-6")
  inspect(amplitude_dbfs(8192), content="-12")
  inspect(amplitude_dbfs(1024), content="-30")
  inspect(amplitude_dbfs(1), content="-60")
  inspect(amplitude_dbfs(0), content="-60")
}

///|
test "signal labels match the meter zones" {
  inspect(signal_label(-60), content="VERY LOW")
  inspect(signal_label(-45), content="VERY LOW")
  inspect(signal_label(-44), content="LOW")
  inspect(signal_label(-30), content="LOW")
  inspect(signal_label(-29), content="GOOD")
  inspect(signal_label(-6), content="GOOD")
  inspect(signal_label(-5), content="HOT")
}

///|
test "response cycles predictably" {
  inspect(response_label(next_response(Fast)), content="MEDIUM")
  inspect(response_label(next_response(Medium)), content="SLOW")
  inspect(response_label(next_response(Slow)), content="FAST")
}

///|
test "meter coordinate maps minus sixty to zero across the full bar" {
  inspect(db_to_meter_x(-60, 20, 180), content="20")
  inspect(db_to_meter_x(-30, 20, 180), content="110")
  inspect(db_to_meter_x(0, 20, 180), content="200")
}

///|
test "RMS dBFS uses sustained energy instead of a single peak" {
  inspect(rms_dbfs(268435456L, 1), content="-6")
  inspect(rms_dbfs(67108864L, 1), content="-12")
  // One full-scale sample among 1024 otherwise-silent samples is about -30 dBFS RMS.
  inspect(rms_dbfs(1073741824L, 1024), content="-30")
}

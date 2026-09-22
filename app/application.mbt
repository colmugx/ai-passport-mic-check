///|
/// Explicit promotion of Application trait methods.
pub extend App with @application.Application::{
  audio_output,
  render,
  button,
  button_event,
  update,
}

///|
pub impl @application.Application for App with fn update(
  self : App,
  ctx : @application.FrameContext,
) -> Unit {
  self.advance(ctx.now_us)
}

///|
/// MIC CHECK uses semantic gestures from `button_event`; raw edges are not
/// needed for product behavior.
pub impl @application.Application for App with fn button(
  _self : App,
  _button : @input.Button,
  _pressed : Bool,
) -> Unit {

}

///|
pub impl @application.Application for App with fn button_event(
  self : App,
  button : @input.Button,
  event : @input.ButtonEvent,
) -> Unit {
  self.handle_button_event(button, event)
}

///|
pub impl @application.Application for App with fn render(
  self : App,
  battery_percent : Int?,
) -> @graphics.FrameView {
  self.draw(battery_percent)
  self.canvas.frame_view()
}

///|
/// This utility plays no sound.
pub impl @application.Application for App with fn audio_output(_self : App) -> @application.AudioOutput? {
  None
}

///|
/// Application entry loaded by CLI-generated Host adapters.
pub fn passport_main() -> &@application.Application {
  App::new()
}

# AI Passport Mic Check

A compact microphone input diagnostic for [AI Passport](https://github.com/colmugx/ai-passport.mbt), written in MoonBit.

MIC CHECK displays the live microphone level as **RMS dBFS**, together with peak hold and capture drop telemetry. It runs through the same portable application on the Web Host and supported AI Passport hardware.

## What it shows

- live RMS input level from approximately `-60` to `0 dBFS`;
- `LOW`, `GOOD`, and `HOT` level regions;
- digital peak hold;
- microphone capture dropped-sample count;
- selectable meter release speed;
- optional host battery percentage;
- explicit microphone availability / permission state.

`dBFS` is a digital level referenced to full-scale PCM. **MIC CHECK is not a calibrated dB SPL sound-level meter.** Converting dBFS to acoustic SPL requires a known acoustic reference and a device-specific calibration offset.

## Controls

| Input | Action |
| --- | --- |
| OK click | Start / stop microphone capture |
| Up click | Cycle meter response: FAST / MEDIUM / SLOW |
| Down click | Reset peak hold and the displayed DROP counter |
| OK double-click | Freeze / resume the displayed reading while capture continues |
| OK long-press | Stop capture and reset the utility |

On Web, the browser may request microphone permission after capture is started.

## Meter behavior

The main reading uses RMS energy from up to 1024 recent PCM16 samples, about 64 ms at 16 kHz. This makes the primary meter reflect sustained input energy instead of letting a single button click, handling transient, or isolated sample spike dominate the reading.

Peak hold remains a true digital sample peak, which is useful for spotting clipping. While the display is frozen, MIC CHECK continues draining microphone samples so the freeze feature itself does not cause capture-ring overflow.

Starting a new capture session resets the live level and peak hold.

## Requirements

- MoonBit toolchain
- `colmugx/ai-passport@0.2.6`

Install dependencies and run the project checks:

```sh
moon update
moon check --target native
moon test --target native
moon check --target wasm
moon test --target wasm
```

## Run in the Web Host

```sh
moonx colmugx/ai-passport/cmd/passport@0.2.6 dev --host web
```

Open the URL printed by the CLI, allow microphone access when prompted, then press OK to start capture.

## Build for FoloToy AI Passport

Check the host environment and build the firmware workspace:

```sh
moonx colmugx/ai-passport/cmd/passport@0.2.6 doctor --host folotoy-ai-passport
moonx colmugx/ai-passport/cmd/passport@0.2.6 build --host folotoy-ai-passport
```

With the board connected, use the generated scripts:

```sh
.passport/folotoy-ai-passport/flash.sh -p PORT
.passport/folotoy-ai-passport/monitor.sh -p PORT
```

Generated Host workspaces live under `.passport/` and `passport-generated/`; they are build output and are not part of the source repository.

## Project layout

```text
moon.mod
passport.toml
app/
  app.mbt
  application.mbt
  draw.mbt
  level_wbtest.mbt
  moon.pkg
```

The application contains no sound resources and returns no audio output. It only uses the portable AI Passport microphone, display, input, and battery capabilities.

## License

Apache-2.0.

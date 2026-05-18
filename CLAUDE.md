# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A **Flutter package** (not an app) published to pub.dev as `flutter_voice_recorder_ui`. It provides a WhatsApp-style hold-to-record voice button that emits **raw PCM bytes as a stream while the user is still talking**, so the bytes can be piped to streaming voice-AI APIs (OpenAI Realtime, Gemini Live, Whisper, Deepgram). Package source is `lib/`; a runnable demo lives in `example/`.

## Common commands

From the package root (`/Users/apple/Flutter/flutter_voice_recorder_ui`):

```bash
flutter pub get
flutter analyze
flutter test
flutter test test/flutter_voice_recorder_ui_test.dart -p "VoiceRecorderConfig"   # single test group
flutter pub publish --dry-run     # validate before publish
```

To exercise the widget on a device/simulator (you can't really test mic capture in unit tests):

```bash
cd example
flutter pub get
flutter run                       # iOS/Android/macOS — web is NOT supported
```

The example **needs real mic permissions**, configured per platform in `example/ios/Runner/Info.plist`, `example/android/app/src/main/AndroidManifest.xml`, and both `.entitlements` files under `example/macos/Runner/`. The README has the exact snippets — anyone consuming the package must repeat the same platform setup in their own app.

## Architecture

The package has a deliberate **two-layer split**:

1. **`VoiceRecorderController`** (`lib/src/voice_recorder_controller.dart`) — headless audio engine. Wraps the `record` package's `AudioRecorder`, owns mic permission flow (via `permission_handler`), and exposes three broadcast streams: `stateStream` (idle/recording/error), `amplitudeStream` (dBFS-to-0..1 normalized at ~10 Hz, see `_ampSub` mapping `-45..0 dBFS → 0..1`), and `bytesStream` (raw PCM chunks from `startStream()`, cached as a broadcast stream). It can be used directly for custom UIs — `bytesStream` throws `StateError` if accessed before `start()`.

2. **`VoiceRecorderButton`** (`lib/src/voice_recorder_button.dart`) — the WhatsApp-style hold-to-record widget. Owns its own `VoiceRecorderController` instance, the gesture machine, and the animation. Composes the smaller primitives (`WaveformPainter`, `DottedWaveform`, `LockRail`, `LockedRecordingBar`, `RecordingTimer`, `SlideToCancelHint`) — each kept in its own file under `lib/src/` and re-exported from `lib/flutter_voice_recorder_ui.dart` so consumers can build alternative UIs from the same parts.

### State machine inside `VoiceRecorderButton`

Three visual modes that callers also observe via `onRecordingStateChanged` / `onRecordingLockedChanged`:

- **Idle** — small mic icon only.
- **Recording (hold)** — pill expands left of the mic, showing timer + live waveform. Drag updates compute `dx`/`dy` from the original press origin:
  - `dx > cancelSlideThreshold` ⇒ `_willCancel` flag flips, heavy haptic, pill fades; releasing finger then cancels instead of completing.
  - `dy > lockSlideThreshold` (and not currently sliding to cancel) ⇒ `_engageLock()` transitions to locked mode.
- **Locked** — `LockedRecordingBar` replaces the pill+mic: delete, pause/resume, send buttons. Recording continues without the user holding.

### Gesture nuance

`_MicButton` uses a raw `Listener` (not `GestureDetector`) and a **180 ms hold delay** (`_holdDelay`) before `_startRecording()` fires. This prevents accidental taps from triggering mic permission prompts. The drag origin is captured on `onPointerDown` and dx/dy are measured against it — they are **not** deltas between frames.

### Streaming-while-recording contract

`_finishRecording()` grabs `_controller.bytesStream` *before* calling `_controller.stop()`, then wraps both into a `VoiceRecorderResult` for the callback. Because the underlying stream is a `asBroadcastStream()` made at `start()` time, late listeners only see chunks emitted after they subscribe — that is the intended design for "stream to API while recording", but means consumers who want the full audio buffer need to subscribe inside `onRecordingComplete` synchronously and accumulate. The README's Whisper example demonstrates this.

### Defaults are intentional

`VoiceRecorderConfig` defaults to **16 kHz / 16-bit / mono PCM** because that's what OpenAI Realtime / Gemini Live / Whisper expect. Don't "modernize" these to higher sample rates without a reason — the test `defaults are tuned for voice-AI streaming` will fail and downstream API integrations will break.

## Conventions

- `analysis_options.yaml` enforces `prefer_const_constructors` and `prefer_const_literals_to_create_immutables`. Most widget trees in this codebase aggressively use `const` — keep it that way.
- Public API surface is **only** what `lib/flutter_voice_recorder_ui.dart` re-exports. Files in `lib/src/` are otherwise private to consumers. When adding new public types, export them explicitly with `show ...`.
- Bump `pubspec.yaml` `version` + add a `CHANGELOG.md` entry for any user-visible change (see `PUBLISHING.md` for the release loop).

# flutter_voice_recorder_ui

[![pub package](https://img.shields.io/pub/v/flutter_voice_recorder_ui.svg)](https://pub.dev/packages/flutter_voice_recorder_ui)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios-blue)](#)

A **WhatsApp-style hold-to-record voice button** with a live waveform animation,
designed for **streaming raw PCM bytes to voice-AI APIs** (OpenAI Realtime,
Gemini Live, Whisper, Deepgram).

> Born out of a real production voice-AI assistant where I needed a recorder
> that streams chunks *while* the user is still talking — not after they
> release the button.

---

## ✨ Features

- 🎙️ **Long-press to record** — quick taps are ignored so you don't trigger
  the mic permission prompt by accident
- 〰️ **Live amplitude-driven waveform** (~10 fps from the real mic level)
- ⬅️ **Slide-to-cancel** — the mic visually slides over the pill, occluding
  "Slide to cancel" as you drag further. Rubber-band resistance past the
  threshold so it never feels stuck.
- 🔒 **Slide-up-to-lock** — the lock rail grows like an elevator shaft as
  your finger rises; the mic follows your finger in both axes.
- 🤲 **Hands-free locked bar** with pause / delete / send
- 📡 **Streaming PCM bytes** — pipe to voice-AI APIs while the user is still
  talking
- 🎚️ Defaults tuned for LLM voice endpoints (**16 kHz / 16-bit / mono**)
- 🛡️ Built-in mic permission handling
- 🧩 **Theme-adaptive defaults** — picks up your app's `colorScheme.primary`
  automatically. All colors / sizes / thresholds remain overridable.

---

## 📸 Demo

![Demo](demo.gif)

*The mic button picks up `Theme.colorScheme.primary` automatically — here
it's Material 3's default indigo. Pass `micColor` for any other color.*

---

## 🚀 Getting Started

### 1. Install

```yaml
dependencies:
  flutter_voice_recorder_ui: ^0.1.0
```

### 2. Platform setup

**iOS** — add to `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need the microphone to record your voice messages.</string>
```

**Android** — add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

**macOS** — add to `macos/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need the microphone to record your voice messages.</string>
```

Add microphone access to **both** `macos/Runner/DebugProfile.entitlements` and
`Release.entitlements` (required for the sandbox):

```xml
<key>com.apple.security.device.audio-input</key>
<true/>
```

If permission was denied earlier, enable the mic for your app in
**System Settings → Privacy & Security → Microphone**, then restart the app.

### 3. Use the widget

```dart
import 'package:flutter_voice_recorder_ui/flutter_voice_recorder_ui.dart';

VoiceRecorderButton(
  onRecordingComplete: (result) {
    print('Recorded ${result.durationMs}ms');
    result.bytesStream.listen((chunk) {
      // chunk is Uint8List of raw 16-bit PCM bytes
    });
  },
  onRecordingCancelled: () => print('Cancelled'),
  onPermissionDenied: () => print('Mic denied'),
)
```

That's it. Hold to record, release to finish, slide left to cancel, slide up to lock.

---

## 👆 Gestures

| You do                                                | What happens                                                                                                                                   |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tap & release** (under ~120 ms)                     | Nothing. Quick taps are filtered so the mic permission prompt isn't triggered accidentally.                                                    |
| **Long-press** (hold beyond ~120 ms)                  | Recording starts. The pill expands left of the mic; the lock rail appears above it.                                                            |
| **Release** after a real long-press                   | Recording stops and `onRecordingComplete` fires with the duration + the still-open byte stream.                                                |
| **Slide ⬅ left while holding**                        | The mic slides over the pill. Past `cancelSlideThreshold` the mic goes red and the pill dims. Release here ⇒ `onRecordingCancelled`.           |
| **Slide ⬆ up while holding**                          | The mic rises with your finger; the lock rail stretches like an elevator shaft. Past `lockSlideThreshold` the recording **locks** hands-free.  |
| **In locked mode**                                    | Pause/resume, delete, or send via the on-screen controls.                                                                                      |

All thresholds are configurable. Haptics fire on press, on threshold crossings, and on release.

---

## 🤖 Streaming to voice-AI APIs

The byte stream emits chunks **while the user is still recording**, so you can
send them to a streaming API in real time.

### OpenAI Realtime

```dart
VoiceRecorderButton(
  onRecordingComplete: (result) {
    result.bytesStream.listen((chunk) {
      openAiSocket.add(jsonEncode({
        'type': 'input_audio_buffer.append',
        'audio': base64Encode(chunk),
      }));
    });
  },
)
```

### Google Gemini Live

```dart
result.bytesStream.listen((chunk) {
  geminiLiveSession.sendRealtimeInput(
    media: Blob(mimeType: 'audio/pcm', data: chunk),
  );
});
```

### Whisper (batch — collect first, then send)

```dart
final buffer = <int>[];
result.bytesStream.listen(buffer.addAll, onDone: () async {
  final bytes = Uint8List.fromList(buffer);
  await whisperClient.transcribe(bytes);
});
```

---

## ⚙️ Configuration

Defaults are **theme-adaptive** — out of the box the mic button uses
`Theme.colorScheme.primary`, so the button matches your app. Override
anything you want:

```dart
VoiceRecorderButton(
  onRecordingComplete: (r) { /* ... */ },
  config: const VoiceRecorderConfig(
    sampleRate: 24000,        // Match your API's expected rate
    numChannels: 1,
    encoder: AudioEncoder.pcm16bits,
  ),
  size: 56,
  micColor: Color(0xFF25D366),         // WhatsApp green (or use your brand)
  pillColor: Colors.white,
  waveformColor: Color(0xFF25D366),
  timerColor: Color(0xFF111B21),
  recordingIndicatorColor: Color(0xFFEF4444),  // pulsing red mic in pill
  pillMicGap: 12,
  cancelSlideThreshold: 96,
  lockSlideThreshold: 48,
  enableLock: true,
  hapticFeedback: true,
)
```

The locked-recording bar (the hands-free UI that appears after slide-up) is
also themable:

```dart
LockedRecordingBar(
  // ...required fields...
  waveformColor: Color(0xFF8696A0),
  sendButtonColor: Color(0xFF25D366),
)
```

---

## 🧪 Using the controller directly

If you don't want the widget — say, for a custom UI — drive the controller
yourself:

```dart
final controller = VoiceRecorderController();

await controller.start();
controller.bytesStream.listen(sendToApi);
controller.amplitudeStream.listen((amp) => drawBar(amp));

await controller.stop();
await controller.dispose();
```

---

## 📋 Roadmap

- [ ] Optional file output (m4a / wav) for non-streaming use cases
- [ ] Waveform "history" view of completed recordings
- [ ] Web platform support
- [ ] Built-in OpenAI Realtime / Gemini Live adapters

PRs welcome.

---

## 📄 License

MIT — see [LICENSE](LICENSE).

## 🙋 About

Built by [Amir Hameed](https://github.com/amirhameed), Senior Flutter
Developer. Extracted from production voice-AI work on the Saleforge assistant.

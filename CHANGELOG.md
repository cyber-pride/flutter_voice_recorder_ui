# Changelog

## 0.2.0 — WhatsApp parity & general-purpose defaults

**Default behavior changes** (existing apps may see different visuals):
- Recording now requires a ~120 ms long-press; a quick tap is discarded. This
  stops accidental presses from triggering the mic permission prompt.
- Default `micColor` is now `Theme.colorScheme.primary` (was WhatsApp green).
  Pass `micColor: Color(0xFF25D366)` explicitly for the WhatsApp look.
- Default `timerColor` follows `Theme.colorScheme.onSurface`.

**WhatsApp-style interaction polish:**
- Lock rail **grows like an elevator** as the user slides up — the pill
  stretches from its base height while staying anchored to the current mic
  position. The chevron at the bottom fades as you approach lock engage.
- Mic button **follows your finger in both axes** (was horizontal-only). The
  lock rail's bottom tracks the rising mic so they stay visually connected.
- Recording pill **stays put during slide-to-cancel** — the mic slides over
  it, occluding "Slide to cancel" progressively (matches real WhatsApp; was
  translating both together).
- **Rubber-band resistance** past the cancel threshold — the mic keeps
  tracking the finger at 30% resistance instead of clamping at a hard cap.

**Snappier feel:**
- Pill expand: 240 → 150 ms.
- Mic press scale: 180 → 120 ms (curve changed to `easeOutCubic` — clean
  snap, no overshoot).
- Lock rail height tracks the finger pixel-perfect every frame
  (previously used an 80 ms `AnimatedContainer` tween — visibly laggy).
- Subtle press visual during the 120 ms hold-detection window so the press
  is acknowledged even before recording starts.

**New API:**
- `VoiceRecorderButton.recordingIndicatorColor` — color of the small pulsing
  mic icon inside the recording pill (defaults to a universal red `#EF4444`).
- `LockedRecordingBar.waveformColor` — dotted waveform color in locked mode.
- `LockedRecordingBar.sendButtonColor` — circular send button color.
- `LockRail.extension` — vertical drag distance, drives the growing-elevator
  effect.

**Bug fixes:**
- Release now reliably stops the recording even when the user releases
  before the mic permission prompt finishes (was leaving the timer running
  forever because `bytesStream` threw on early access).
- Widget height no longer shrinks 96 px when crossing into the cancel zone
  (was causing a layout jump that felt like the gesture got "stuck").
- Lock pill chevron no longer overflows its container (base height
  60 → 76 so two 22-px icons fit).
- UI resets instantly on release; the slow native `MediaRecorder.cancel()`
  now runs in the background instead of blocking the visible reset.
- Idle mic icon is now `Icons.mic_none` (outlined), recording uses filled
  `Icons.mic`, with a snappy scale-swap transition.

## 0.1.1 — WhatsApp UI polish

- Recording pill now matches WhatsApp: pulsing pink mic + timer + slide-to-cancel
  (waveform moved out — it only appears in locked mode, where it belongs)
- Taller, more prominent lock rail (40×~90) with a gently bouncing up-chevron
- Locked recording bar uses real circular `InkWell` hit targets and an
  animated pause/play swap
- Idle button now correctly shows `Icons.mic_none` (outlined) and switches to
  filled `Icons.mic` when recording
- `LockedRecordingBar` gains `waveformColor` and `sendButtonColor` parameters
- `DottedWaveform` scrolls newest-on-right like the live waveform, with
  amplitude-driven dot size variation
- Snappier overall: pill expand 300 → 240 ms, mic press 150 → 130 ms

## 0.1.0 — Initial release

- Hold-to-record `VoiceRecorderButton` widget
- Live amplitude-driven waveform animation
- Slide-to-cancel gesture
- Streaming raw PCM byte output via `bytesStream`
- Configurable sample rate, channels, encoder
- Built-in mic permission handling
- `VoiceRecorderController` for headless / custom-UI use

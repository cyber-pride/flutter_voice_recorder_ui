/// flutter_voice_recorder_ui
///
/// A WhatsApp-style hold-to-record voice button with live waveform animation.
/// Outputs raw PCM bytes for streaming to voice-AI APIs.
library flutter_voice_recorder_ui;

export 'src/dotted_waveform.dart' show DottedWaveform;
export 'src/lock_rail.dart' show LockRail;
export 'src/locked_recording_bar.dart' show LockedRecordingBar;
export 'src/recording_timer.dart' show RecordingTimer;
export 'src/slide_to_cancel_hint.dart' show SlideToCancelHint;
export 'src/voice_recorder_button.dart';
export 'src/voice_recorder_controller.dart' show
    VoiceRecorderConfig,
    VoiceRecorderController,
    VoiceRecorderState;
export 'src/waveform_painter.dart' show WaveformPainter;

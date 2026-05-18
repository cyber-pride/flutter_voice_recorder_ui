import 'dart:async';
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Configuration for the audio recording.
///
/// Defaults are tuned for streaming to OpenAI / Gemini voice APIs:
/// 16 kHz, 16-bit PCM, mono — the format most LLM voice endpoints expect.
class VoiceRecorderConfig {
  const VoiceRecorderConfig({
    this.sampleRate = 16000,
    this.numChannels = 1,
    this.bitRate = 128000,
    this.encoder = AudioEncoder.pcm16bits,
  });

  final int sampleRate;
  final int numChannels;
  final int bitRate;
  final AudioEncoder encoder;

  RecordConfig toRecordConfig() => RecordConfig(
        encoder: encoder,
        sampleRate: sampleRate,
        numChannels: numChannels,
        bitRate: bitRate,
      );
}

/// State of the recorder, exposed via [VoiceRecorderController.stateStream].
enum VoiceRecorderState { idle, recording, error }

/// Controls audio recording and exposes the raw PCM byte stream + amplitude
/// stream for waveform rendering.
///
/// Typical usage:
/// ```dart
/// final controller = VoiceRecorderController();
/// await controller.start();
/// controller.bytesStream.listen((chunk) => sendToApi(chunk));
/// await controller.stop();
/// ```
class VoiceRecorderController {
  VoiceRecorderController({VoiceRecorderConfig? config})
      : _config = config ?? const VoiceRecorderConfig(),
        _recorder = AudioRecorder();

  final VoiceRecorderConfig _config;
  final AudioRecorder _recorder;

  final _stateController = StreamController<VoiceRecorderState>.broadcast();
  final _amplitudeController = StreamController<double>.broadcast();

  StreamSubscription<Uint8List>? _byteSub;
  StreamSubscription<Amplitude>? _ampSub;
  Stream<Uint8List>? _rawStream;

  VoiceRecorderState _state = VoiceRecorderState.idle;
  VoiceRecorderState get state => _state;

  bool _paused = false;
  bool get isPaused => _paused;

  /// Emits recorder state transitions.
  Stream<VoiceRecorderState> get stateStream => _stateController.stream;

  /// Emits a normalized amplitude (0.0 – 1.0) ~10 times per second. Drive
  /// your waveform widget off this.
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Emits raw PCM byte chunks while recording. Pipe these straight to your
  /// streaming voice API (e.g. OpenAI Realtime, Gemini Live).
  Stream<Uint8List> get bytesStream {
    if (_rawStream == null) {
      throw StateError(
        "bytesStream accessed before start(). Call start() first.",
      );
    }
    return _rawStream!;
  }

  /// Requests mic permission. Returns true if granted.
  Future<bool> requestPermission() async {
    if (await _recorder.hasPermission()) return true;

    final status = await Permission.microphone.request();
    if (status.isGranted) return true;

    // Re-check after permission_handler (needed on some macOS setups).
    return _recorder.hasPermission(request: false);
  }

  /// Begins recording. Throws [StateError] if permission is denied.
  Future<void> start() async {
    if (_state == VoiceRecorderState.recording) return;

    final granted = await requestPermission();
    if (!granted) {
      _setState(VoiceRecorderState.error);
      throw StateError("Microphone permission denied.");
    }

    try {
      _rawStream = (await _recorder.startStream(_config.toRecordConfig()))
          .asBroadcastStream();

      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        // record returns amplitudes in dBFS (negative numbers, 0 = loudest).
        // Map roughly -45..0 dBFS to 0..1 for the waveform.
        const minDb = -45.0;
        final normalized = ((amp.current - minDb) / -minDb).clamp(0.0, 1.0);
        _amplitudeController.add(normalized);
      });

      _paused = false;
      _setState(VoiceRecorderState.recording);
    } catch (e) {
      _setState(VoiceRecorderState.error);
      rethrow;
    }
  }

  /// Stops recording. Returns the total duration in milliseconds.
  Future<int> stop() async {
    if (_state != VoiceRecorderState.recording) return 0;
    final start = DateTime.now();
    await _recorder.stop();
    await _ampSub?.cancel();
    await _byteSub?.cancel();
    _ampSub = null;
    _byteSub = null;
    _paused = false;
    _setState(VoiceRecorderState.idle);
    return DateTime.now().difference(start).inMilliseconds;
  }

  /// Pauses an active recording (locked / hands-free mode).
  Future<void> pause() async {
    if (_state != VoiceRecorderState.recording || _paused) return;
    await _recorder.pause();
    _paused = true;
  }

  /// Resumes after [pause].
  Future<void> resume() async {
    if (_state != VoiceRecorderState.recording || !_paused) return;
    await _recorder.resume();
    _paused = false;
  }

  /// Cancels recording without emitting any captured audio.
  Future<void> cancel() async {
    if (_state != VoiceRecorderState.recording) return;
    await _recorder.cancel();
    await _ampSub?.cancel();
    await _byteSub?.cancel();
    _ampSub = null;
    _byteSub = null;
    _rawStream = null;
    _paused = false;
    _setState(VoiceRecorderState.idle);
  }

  void _setState(VoiceRecorderState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
    await _stateController.close();
    await _amplitudeController.close();
  }
}

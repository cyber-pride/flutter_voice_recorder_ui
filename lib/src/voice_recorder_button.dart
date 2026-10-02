import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lock_rail.dart';
import 'locked_recording_bar.dart';
import 'recording_timer.dart';
import 'slide_to_cancel_hint.dart';
import 'voice_recorder_controller.dart';

/// Result emitted when a recording completes successfully.
class VoiceRecorderResult {
  const VoiceRecorderResult({
    required this.durationMs,
    this.bytesStream,
    this.path,
  });

  final int durationMs;
  final Stream<Uint8List>? bytesStream;
  final String? path;
}

/// WhatsApp-style hold-to-record voice button with slide-to-cancel and slide-up-to-lock.
class VoiceRecorderButton extends StatefulWidget {
  const VoiceRecorderButton({
    super.key,
    required this.onRecordingComplete,
    this.onRecordingCancelled,
    this.onPermissionDenied,
    this.onRecordingStateChanged,
    this.onRecordingLockedChanged,
    this.config,
    this.micColor,
    this.pillColor,
    this.waveformColor,
    this.timerColor,
    this.recordingIndicatorColor,
    this.deleteIconColor,
    this.pauseIconColor,
    this.sendIconColor,
    this.micBackgroundColor = Colors.transparent,
    this.micIcon = Icons.mic,
    this.idleMicIcon = Icons.mic_none,
    this.pulsingMicIcon = Icons.mic,
    this.lockIcon = Icons.lock,
    this.lockOpenIcon = Icons.lock_open_outlined,
    this.lockArrowIcon = Icons.keyboard_arrow_up_rounded,
    this.deleteIcon = Icons.delete_outline,
    this.pauseIcon = Icons.pause_rounded,
    this.playIcon = Icons.play_arrow_rounded,
    this.sendIcon = Icons.send_rounded,
    this.cancelChevronIcon = Icons.chevron_left,
    this.size = 48,
    this.pillMicGap = 12,
    this.cancelSlideThreshold = 96,
    this.lockSlideThreshold = 48,
    this.enableLock = true,
    this.enableBoxShadow = true,
    this.hapticFeedback = true,
  });

  final void Function(VoiceRecorderResult result) onRecordingComplete;
  final VoidCallback? onRecordingCancelled;
  final VoidCallback? onPermissionDenied;
  final ValueChanged<bool>? onRecordingStateChanged;
  final ValueChanged<bool>? onRecordingLockedChanged;
  final VoiceRecorderConfig? config;

  final Color? micColor;
  final Color? pillColor;
  final Color? waveformColor;
  final Color? timerColor;

  /// Color of the small pulsing mic icon shown inside the recording pill
  /// (the "you're recording" indicator). Defaults to a universal red.
  final Color? recordingIndicatorColor;

  final Color? deleteIconColor;
  final Color? pauseIconColor;
  final Color? sendIconColor;

  /// Background color of the mic button when idle (not recording).
  /// Defaults to [Colors.transparent].
  final Color micBackgroundColor;

  final IconData micIcon;
  final IconData idleMicIcon;
  final IconData pulsingMicIcon;
  final IconData lockIcon;
  final IconData lockOpenIcon;
  final IconData lockArrowIcon;
  final IconData deleteIcon;
  final IconData pauseIcon;
  final IconData playIcon;
  final IconData sendIcon;
  final IconData cancelChevronIcon;

  final double size;
  final double pillMicGap;
  final double cancelSlideThreshold;
  final double lockSlideThreshold;
  final bool enableLock;

  /// Whether to show a glow/shadow behind the mic button while recording.
  /// Defaults to [true].
  final bool enableBoxShadow;

  final bool hapticFeedback;

  @override
  State<VoiceRecorderButton> createState() => _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends State<VoiceRecorderButton>
    with TickerProviderStateMixin {
  static const _fallbackMic = Color(0xFF22C55E);
  static const _defaultPill = Color(0xFFFFFFFF);
  static const _fallbackTimer = Color(0xFF1F2937);
  static const _recordingPink = Color(0xFFEF4444);
  static const _lockRailHeight = 96.0;
  static const _lockedBarHeight = 108.0;

  late final VoiceRecorderController _controller;
  late final AnimationController _expandCtrl;
  late final CurvedAnimation _expandCurve;

  final List<double> _amplitudes = [];
  StreamSubscription<double>? _ampSub;
  Timer? _timerTicker;
  DateTime? _recordStartedAt;

  bool _isRecording = false;
  bool _isLocked = false;
  bool _willCancel = false;
  bool _didCancelHaptic = false;
  double _dragOffsetX = 0;
  double _dragOffsetY = 0;
  double _lockProgress = 0;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = VoiceRecorderController(config: widget.config);
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _expandCurve = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _ampSub = _controller.amplitudeStream.listen((amp) {
      if (!mounted || _controller.isPaused) return;
      setState(() {
        _amplitudes.add(amp);
        if (_amplitudes.length > 120) _amplitudes.removeAt(0);
      });
    });
  }

  void _startTimer() {
    _recordStartedAt = DateTime.now();
    _elapsed = Duration.zero;
    _timerTicker?.cancel();
    void tick() {
      if (!mounted || _recordStartedAt == null || _controller.isPaused) {
        return;
      }
      setState(() {
        _elapsed = DateTime.now().difference(_recordStartedAt!);
      });
    }

    tick();
    _timerTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      tick();
    });
  }

  void _stopTimer() {
    _timerTicker?.cancel();
    _timerTicker = null;
    _recordStartedAt = null;
    _elapsed = Duration.zero;
  }

  void _resetDrag() {
    _dragOffsetX = 0;
    _dragOffsetY = 0;
    _lockProgress = 0;
    _willCancel = false;
    _didCancelHaptic = false;
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    // Update UI first so the pill + lock rail appear instantly on press.
    // Haptic is fire-and-forget so it doesn't block the visible feedback.
    setState(() {
      _isRecording = true;
      _isLocked = false;
      _amplitudes.clear();
      _resetDrag();
    });
    widget.onRecordingStateChanged?.call(true);
    widget.onRecordingLockedChanged?.call(false);
    _startTimer();
    _expandCtrl.forward(from: 0);

    if (widget.hapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    try {
      await _controller.start();
    } on StateError {
      await _rollbackStart();
      widget.onPermissionDenied?.call();
    } catch (_) {
      await _rollbackStart();
      widget.onPermissionDenied?.call();
    }
  }

  Future<void> _rollbackStart() async {
    _stopTimer();
    if (_controller.state == VoiceRecorderState.recording) {
      await _controller.cancel();
    }
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isLocked = false;
      _resetDrag();
    });
    widget.onRecordingStateChanged?.call(false);
    widget.onRecordingLockedChanged?.call(false);
    if (_expandCtrl.status != AnimationStatus.dismissed) {
      await _expandCtrl.reverse();
    }
  }

  void _engageLock() {
    if (_isLocked || !widget.enableLock) return;
    if (widget.hapticFeedback) {
      HapticFeedback.mediumImpact();
    }
    setState(() {
      _isLocked = true;
      _resetDrag();
    });
    widget.onRecordingLockedChanged?.call(true);
    _expandCtrl.forward();
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    try {
      await _controller.cancel();
    } catch (_) {}
    widget.onRecordingCancelled?.call();
    await _endRecordingUi();
  }

  Future<void> _finishRecording() async {
    if (!_isRecording) return;

    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }

    final ready = _controller.state == VoiceRecorderState.recording;
    final isStreamMode =
        _controller.outputMode == VoiceRecorderOutputMode.stream;
    final shouldCancel = _willCancel || !ready;
    Stream<Uint8List>? capturedStream;
    if (!shouldCancel && isStreamMode) {
      try {
        capturedStream = _controller.bytesStream;
      } catch (_) {
        // Stream not ready yet — fall through to cancel path.
      }
    }

    // Reset the UI now so the user feels instant feedback, regardless of
    // how slow the underlying recorder is to tear down.
    await _endRecordingUi();

    // Drive the underlying recorder. If anything throws (slow Android,
    // race condition), swallow it — the UI is already clean.
    try {
      if (shouldCancel || (isStreamMode && capturedStream == null)) {
        await _controller.cancel();
        widget.onRecordingCancelled?.call();
      } else {
        final stopResult = await _controller.stop();
        widget.onRecordingComplete(
          VoiceRecorderResult(
            durationMs: stopResult.durationMs,
            bytesStream: capturedStream,
            path: stopResult.path,
          ),
        );
      }
    } catch (_) {
      try {
        await _controller.cancel();
      } catch (_) {}
      widget.onRecordingCancelled?.call();
    }
  }

  Future<void> _endRecordingUi() async {
    _stopTimer();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isLocked = false;
      _resetDrag();
    });
    widget.onRecordingStateChanged?.call(false);
    widget.onRecordingLockedChanged?.call(false);
    await _expandCtrl.reverse();
  }

  Future<void> _togglePause() async {
    if (_controller.isPaused) {
      await _controller.resume();
    } else {
      await _controller.pause();
    }
    if (mounted) setState(() {});
  }

  /// iOS-style rubber band: full travel up to [threshold], then 30% of any
  /// further pull. Stops the gesture from ever feeling "stuck" at a hard cap.
  double _rubberBand(double value, double threshold) {
    if (value <= 0) return 0;
    if (value <= threshold) return value;
    final overshoot = value - threshold;
    return threshold + overshoot * 0.3;
  }

  void _onDragUpdate(double dx, double dy) {
    if (!_isRecording || _isLocked) return;

    final lockProgress = widget.enableLock
        ? (dy / widget.lockSlideThreshold).clamp(0.0, 1.0)
        : 0.0;

    if (widget.enableLock &&
        dy > widget.lockSlideThreshold &&
        dx < widget.cancelSlideThreshold * 0.5) {
      _engageLock();
      return;
    }

    final offsetX = _rubberBand(dx, widget.cancelSlideThreshold);
    final offsetY = widget.enableLock
        ? _rubberBand(dy, widget.lockSlideThreshold.toDouble())
        : 0.0;
    final willCancel = dx > widget.cancelSlideThreshold;

    if (willCancel != _willCancel && widget.hapticFeedback) {
      if (willCancel && !_didCancelHaptic) {
        HapticFeedback.heavyImpact();
        _didCancelHaptic = true;
      } else if (!willCancel) {
        _didCancelHaptic = false;
      }
    }

    setState(() {
      _lockProgress = lockProgress;
      _dragOffsetX = offsetX;
      _dragOffsetY = offsetY;
      _willCancel = willCancel;
    });
  }

  void _onHoldEnd() {
    if (_isLocked) return;
    _finishRecording();
  }

  @override
  void dispose() {
    _timerTicker?.cancel();
    _ampSub?.cancel();
    _expandCurve.dispose();
    _expandCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mic = widget.micColor ?? (scheme.primary == scheme.surface
        ? _fallbackMic
        : scheme.primary);
    final pill = widget.pillColor ?? _defaultPill;
    final wave = widget.waveformColor ?? mic;
    final timerColor = widget.timerColor ??
        (scheme.onSurface == scheme.surface
            ? _fallbackTimer
            : scheme.onSurface);
    final micSize = widget.size;
    final gap = widget.pillMicGap;

    if (_isLocked) {
      return SizedBox(
        height: _lockedBarHeight,
        width: double.infinity,
        child: LockedRecordingBar(
          elapsed: _elapsed,
          amplitudes: _amplitudes,
          isPaused: _controller.isPaused,
          timerColor: timerColor,
          waveformColor: wave,
          sendButtonColor: widget.micBackgroundColor,
          deleteIconColor: widget.deleteIconColor ?? const Color(0xFF8696A0),
          pauseIconColor: widget.pauseIconColor ?? const Color(0xFFEB4D5C),
          sendIconColor: widget.sendIconColor ?? Colors.white,
          deleteIcon: widget.deleteIcon,
          pauseIcon: widget.pauseIcon,
          playIcon: widget.playIcon,
          sendIcon: widget.sendIcon,
          onDelete: _cancelRecording,
          onPauseResume: _togglePause,
          onSend: _finishRecording,
        ),
      );
    }

    final reserveLockSpace = _isRecording && widget.enableLock;
    final showLockRail = reserveLockSpace && !_willCancel;

    return LayoutBuilder(
      builder: (context, constraints) {
        final reservedRight = micSize + gap;
        final maxPillW =
            (constraints.maxWidth - reservedRight).clamp(0.0, double.infinity);

        return SizedBox(
          height: micSize + (reserveLockSpace ? _lockRailHeight : 0),
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _expandCurve,
            builder: (context, _) {
              final t = _expandCurve.value;
              final pillW = maxPillW * t;
              final showPill = pillW >= 36;

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomRight,
                children: [
                  if (showLockRail)
                    Positioned(
                      right: (micSize - 40) / 2,
                      bottom: micSize + 8 + _dragOffsetY,
                      child: LockRail(
                        progress: _lockProgress,
                        extension: _dragOffsetY,
                        locked: false,
                        lockIcon: widget.lockIcon,
                        lockOpenIcon: widget.lockOpenIcon,
                        lockArrowIcon: widget.lockArrowIcon,
                      ),
                    ),

                  if (showPill)
                    Positioned(
                      right: reservedRight,
                      bottom: 0,
                      child: _RecordingPill(
                        width: pillW,
                        height: micSize,
                        color: pill,
                        willCancel: _willCancel,
                        elapsed: _elapsed,
                        timerColor: timerColor,
                        indicatorColor: widget.recordingIndicatorColor ??
                            _recordingPink,
                        pulsingMicIcon: widget.pulsingMicIcon,
                        cancelChevronIcon: widget.cancelChevronIcon,
                        deleteIcon: widget.deleteIcon,
                      ),
                    ),

                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Transform.translate(
                      offset: Offset(-_dragOffsetX, -_dragOffsetY),
                      child: _MicButton(
                        size: micSize,
                        isRecording: _isRecording,
                        willCancel: _willCancel,
                        micColor: mic,
                        micBackgroundColor: widget.micBackgroundColor,
                        enableBoxShadow: widget.enableBoxShadow,
                        micIcon: widget.micIcon,
                        idleMicIcon: widget.idleMicIcon,
                        onHoldStart: _startRecording,
                        onDrag: _onDragUpdate,
                        onHoldEnd: _onHoldEnd,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _RecordingPill extends StatelessWidget {
  const _RecordingPill({
    required this.width,
    required this.height,
    required this.color,
    required this.willCancel,
    required this.elapsed,
    required this.timerColor,
    required this.indicatorColor,
    required this.pulsingMicIcon,
    required this.cancelChevronIcon,
    required this.deleteIcon,
  });

  final double width;
  final double height;
  final Color color;
  final bool willCancel;
  final Duration elapsed;
  final Color timerColor;
  final Color indicatorColor;
  final IconData pulsingMicIcon;
  final IconData cancelChevronIcon;
  final IconData deleteIcon;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: willCancel ? 0.55 : 1,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.only(left: 14, right: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            _PulsingMicIcon(
              color: willCancel ? Colors.red.shade400 : indicatorColor,
              icon: pulsingMicIcon,
            ),
            const SizedBox(width: 10),
            RecordingTimer(
              elapsed: elapsed,
              showDot: false,
              textStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: timerColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: SlideToCancelHint(
                  willCancel: willCancel,
                  cancelChevronIcon: cancelChevronIcon,
                  deleteIcon: deleteIcon,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingMicIcon extends StatefulWidget {
  const _PulsingMicIcon({
    required this.color,
    required this.icon,
  });

  final Color color;
  final IconData icon;

  @override
  State<_PulsingMicIcon> createState() => _PulsingMicIconState();
}

class _PulsingMicIconState extends State<_PulsingMicIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.55, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: Icon(widget.icon, size: 20, color: widget.color),
    );
  }
}

class _MicButton extends StatefulWidget {
  const _MicButton({
    required this.size,
    required this.isRecording,
    required this.willCancel,
    required this.micColor,
    required this.micBackgroundColor,
    required this.enableBoxShadow,
    required this.micIcon,
    required this.idleMicIcon,
    required this.onHoldStart,
    required this.onDrag,
    required this.onHoldEnd,
  });

  final double size;
  final bool isRecording;
  final bool willCancel;
  final Color micColor;
  final Color micBackgroundColor;
  final bool enableBoxShadow;
  final IconData micIcon;
  final IconData idleMicIcon;
  final Future<void> Function() onHoldStart;
  final void Function(double dx, double dy) onDrag;
  final VoidCallback onHoldEnd;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> {
  static const _holdDelay = Duration(milliseconds: 120);

  Offset? _pressOrigin;
  Timer? _holdTimer;
  bool _isPressed = false;
  // Tracked locally — `widget.isRecording` lags by one frame after
  // _startRecording's setState propagates, dropping drag events in
  // that window. This flag flips the instant the hold fires.
  bool _readyToDrag = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pressOrigin = event.localPosition;
    setState(() => _isPressed = true);
    _holdTimer?.cancel();
    _holdTimer = Timer(_holdDelay, () {
      if (!mounted || _pressOrigin == null) return;
      _readyToDrag = true;
      widget.onHoldStart();
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pressOrigin == null || !_readyToDrag) return;
    final dx = _pressOrigin!.dx - event.localPosition.dx;
    final dy = _pressOrigin!.dy - event.localPosition.dy;
    widget.onDrag(dx, dy);
  }

  void _onPointerUp() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _pressOrigin = null;
    final wasReady = _readyToDrag;
    _readyToDrag = false;
    if (mounted) setState(() => _isPressed = false);
    if (wasReady) {
      widget.onHoldEnd();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isRec = widget.isRecording;
    final bg = isRec
        ? (widget.willCancel ? const Color(0xFFE53935) : widget.micBackgroundColor)
        : widget.micBackgroundColor;
    // Three scale states: idle (small), pressed-but-not-yet-recording
    // (slightly larger so the press feels acknowledged), recording (full).
    final targetScale = isRec ? 1.0 : (_isPressed ? 0.85 : 0.72);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: (_) => _onPointerUp(),
      onPointerCancel: (_) => _onPointerUp(),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.72, end: targetScale),
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            builder: (context, scale, _) {
              return Container(
                width: (isRec) ? (widget.size * scale) : widget.size,
                height: (isRec) ? (widget.size * scale) : widget.size,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  boxShadow: widget.enableBoxShadow && isRec && !widget.willCancel
                      ? [
                          BoxShadow(
                            color: widget.micBackgroundColor.withValues(alpha: 0.45),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 100),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    isRec ? widget.micIcon : widget.idleMicIcon,
                    key: ValueKey(isRec),
                    color: isRec ? Colors.white : widget.micColor,
                    size: widget.size * (isRec ? 0.5 : 0.46),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

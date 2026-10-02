import 'package:flutter/material.dart';

import 'dotted_waveform.dart';
import 'recording_timer.dart';

/// Hands-free recording bar after slide-up lock (WhatsApp-style).
class LockedRecordingBar extends StatelessWidget {
  const LockedRecordingBar({
    super.key,
    required this.elapsed,
    required this.amplitudes,
    required this.isPaused,
    required this.onDelete,
    required this.onPauseResume,
    required this.onSend,
    this.timerColor = const Color(0xFF111B21),
    this.waveformColor = const Color(0xFF8696A0),
    this.sendButtonColor = const Color(0xFF25D366),
    this.deleteIcon = Icons.delete_outline,
    this.pauseIcon = Icons.pause_rounded,
    this.playIcon = Icons.play_arrow_rounded,
    this.sendIcon = Icons.send_rounded,
  });

  final Duration elapsed;
  final List<double> amplitudes;
  final bool isPaused;
  final VoidCallback onDelete;
  final VoidCallback onPauseResume;
  final VoidCallback onSend;
  final Color timerColor;
  final Color waveformColor;
  final Color sendButtonColor;
  final IconData deleteIcon;
  final IconData pauseIcon;
  final IconData playIcon;
  final IconData sendIcon;

  static const _gray = Color(0xFF8696A0);
  static const _pauseRed = Color(0xFFEB4D5C);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
          child: Row(
            children: [
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
              const SizedBox(width: 14),
              Expanded(
                child: DottedWaveform(
                  amplitudes: amplitudes,
                  color: waveformColor,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 56,
          child: Row(
            children: [
              _CircularTap(
                onTap: onDelete,
                size: 44,
                child: Icon(
                  deleteIcon,
                  color: _gray,
                  size: 26,
                ),
              ),
              Expanded(
                child: Center(
                  child: _CircularTap(
                    onTap: onPauseResume,
                    size: 48,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: Icon(
                        isPaused ? playIcon : pauseIcon,
                        key: ValueKey(isPaused),
                        color: _pauseRed,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onSend,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 52,
                  height: 52,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: sendButtonColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: sendButtonColor.withValues(alpha: 0.32),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    sendIcon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircularTap extends StatelessWidget {
  const _CircularTap({
    required this.onTap,
    required this.size,
    required this.child,
  });

  final VoidCallback onTap;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}

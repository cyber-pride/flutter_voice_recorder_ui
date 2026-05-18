import 'package:flutter/material.dart';

/// Elapsed timer with a pulsing red recording dot (WhatsApp-style).
class RecordingTimer extends StatefulWidget {
  const RecordingTimer({
    super.key,
    required this.elapsed,
    this.textStyle,
    this.dotColor = const Color(0xFFFF3B30),
    this.showDot = true,
  });

  final Duration elapsed;
  final TextStyle? textStyle;
  final Color dotColor;
  final bool showDot;

  @override
  State<RecordingTimer> createState() => _RecordingTimerState();
}

class _RecordingTimerState extends State<RecordingTimer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

  static String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.textStyle ??
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF111B21),
          fontFeatures: [FontFeature.tabularFigures()],
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDot) ...[
          FadeTransition(
            opacity: Tween(begin: 0.35, end: 1.0).animate(
              CurvedAnimation(parent: _blinkCtrl, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: widget.dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(_format(widget.elapsed), style: style),
      ],
    );
  }
}

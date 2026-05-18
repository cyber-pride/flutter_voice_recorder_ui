import 'package:flutter/material.dart';

/// Gray dotted timeline used in WhatsApp locked recording mode.
///
/// Newest amplitude is on the right; older samples scroll off the left.
class DottedWaveform extends StatelessWidget {
  const DottedWaveform({
    super.key,
    required this.amplitudes,
    this.color = const Color(0xFF8696A0),
    this.dotSize = 3.0,
    this.gap = 5.0,
    this.height = 26,
  });

  final List<double> amplitudes;
  final Color color;
  final double dotSize;
  final double gap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedWaveformPainter(
        amplitudes: amplitudes,
        color: color,
        dotSize: dotSize,
        gap: gap,
      ),
      size: Size(double.infinity, height),
    );
  }
}

class _DottedWaveformPainter extends CustomPainter {
  _DottedWaveformPainter({
    required this.amplitudes,
    required this.color,
    required this.dotSize,
    required this.gap,
  });

  final List<double> amplitudes;
  final Color color;
  final double dotSize;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.6);
    final stride = dotSize + gap;
    final slots = (size.width / stride).floor().clamp(8, 400);
    final centerY = size.height / 2;

    final start = amplitudes.length > slots ? amplitudes.length - slots : 0;
    final visible = amplitudes.sublist(start);
    final emptySlots = slots - visible.length;

    for (var i = 0; i < slots; i++) {
      final amp = i < emptySlots
          ? 0.12
          : visible[i - emptySlots].clamp(0.0, 1.0);
      final shaped = amp < 0.08 ? amp * 2.0 : amp;
      final r = (dotSize * 0.5) + shaped * (dotSize * 0.9);
      final x = i * stride + dotSize;
      canvas.drawCircle(Offset(x, centerY), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedWaveformPainter old) =>
      old.amplitudes != amplitudes ||
      old.color != color ||
      old.dotSize != dotSize ||
      old.gap != gap;
}

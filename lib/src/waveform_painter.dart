import 'package:flutter/material.dart';

/// Paints a horizontal bar waveform from a rolling list of normalized
/// amplitudes (0.0 – 1.0). Newest sample is on the right (WhatsApp-style).
class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.amplitudes,
    required this.barColor,
    this.barWidth = 2.5,
    this.barGap = 1.5,
    this.minBarHeight = 3.0,
  });

  final List<double> amplitudes;
  final Color barColor;
  final double barWidth;
  final double barGap;
  final double minBarHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty || size.width <= 0) return;

    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final stride = barWidth + barGap;
    final maxBars = (size.width / stride).floor().clamp(1, 999);
    final start =
        amplitudes.length > maxBars ? amplitudes.length - maxBars : 0;
    final visible = amplitudes.sublist(start);

    final totalWidth = visible.length * stride - barGap;
    final offsetX = size.width - totalWidth;
    final centerY = size.height / 2;
    final radius = Radius.circular(barWidth / 2);

    for (var i = 0; i < visible.length; i++) {
      final amp = visible[i].clamp(0.0, 1.0);
      // Slight curve so quiet audio still shows movement (WhatsApp feel).
      final shaped = amp < 0.08 ? amp * 2.5 : amp;
      final h = (shaped * size.height * 0.92).clamp(minBarHeight, size.height);
      final x = offsetX + i * stride;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - h / 2, barWidth, h),
        radius,
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter old) =>
      old.amplitudes != amplitudes ||
      old.barColor != barColor ||
      old.barWidth != barWidth;
}

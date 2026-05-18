import 'package:flutter/material.dart';

/// Animated « chevrons + label, matching WhatsApp slide-to-cancel.
///
/// Adapts to available width: chevrons only when narrow, full label when wide.
class SlideToCancelHint extends StatefulWidget {
  const SlideToCancelHint({
    super.key,
    required this.willCancel,
    this.color,
    this.fontSize = 13,
  });

  final bool willCancel;
  final Color? color;
  final double fontSize;

  @override
  State<SlideToCancelHint> createState() => _SlideToCancelHintState();
}

class _SlideToCancelHintState extends State<SlideToCancelHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _chevronCtrl;

  @override
  void initState() {
    super.initState();
    _chevronCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _chevronCtrl.dispose();
    super.dispose();
  }

  Widget _chevrons(Color color, {required int count}) {
    return AnimatedBuilder(
      animation: _chevronCtrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (i) {
            final phase = (_chevronCtrl.value + i * 0.2) % 1.0;
            final opacity = 0.35 + 0.65 * (1 - phase);
            return Opacity(
              opacity: opacity.clamp(0.2, 1.0),
              child: Icon(
                Icons.chevron_left,
                size: 22,
                color: color.withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const Color(0xFF8696A0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;

        if (widget.willCancel) {
          if (!maxW.isFinite || maxW < 24) {
            return Icon(
              Icons.delete_outline,
              size: 20,
              color: Colors.red.shade600,
            );
          }
          if (maxW < 88) {
            return Icon(
              Icons.delete_outline,
              size: 20,
              color: Colors.red.shade600,
            );
          }
          return SizedBox(
            width: maxW,
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.red.shade600,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Release to cancel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (!maxW.isFinite) {
          return _wideSlideHint(color);
        }
        if (maxW < 28) return const SizedBox.shrink();
        if (maxW < 72) return _chevrons(color, count: 1);
        if (maxW < 110) return _chevrons(color, count: 2);

        return SizedBox(
          width: maxW,
          child: Row(
            children: [
              _chevrons(color, count: 3),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  'Slide to cancel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    color: color,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _wideSlideHint(Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chevrons(color, count: 3),
        const SizedBox(width: 2),
        Text(
          'Slide to cancel',
          style: TextStyle(
            fontSize: widget.fontSize,
            color: color,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

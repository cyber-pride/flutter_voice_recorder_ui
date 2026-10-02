import 'package:flutter/material.dart';

/// Vertical pill above the mic — slide up to lock (WhatsApp-style).
///
/// The pill grows in height as [extension] increases, mimicking the
/// "rising elevator" feel where the mic climbs toward the lock target.
/// The lock icon stays anchored to the top of the pill, the chevron to
/// the bottom (and fades out as the drag progresses).
class LockRail extends StatefulWidget {
  const LockRail({
    super.key,
    required this.progress,
    this.extension = 0,
    this.locked = false,
    this.lockIcon = Icons.lock,
    this.lockOpenIcon = Icons.lock_open_outlined,
    this.lockArrowIcon = Icons.keyboard_arrow_up_rounded,
  });

  /// 0.0 – 1.0 while sliding up toward lock. Used to fade the chevron
  /// hint and tint the lock icon.
  final double progress;

  /// Extra pixels added to the pill's height — wire this to the user's
  /// vertical drag distance so the rail grows as they slide up.
  final double extension;

  final bool locked;
  final IconData lockIcon;
  final IconData lockOpenIcon;
  final IconData lockArrowIcon;

  @override
  State<LockRail> createState() => _LockRailState();
}

class _LockRailState extends State<LockRail>
    with SingleTickerProviderStateMixin {
  static const _gray = Color(0xFF8696A0);
  static const _green = Color(0xFF25D366);
  static const _baseHeight = 76.0;

  late final AnimationController _hintCtrl;

  @override
  void initState() {
    super.initState();
    _hintCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _hintCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.progress.clamp(0.0, 1.0);
    final ext = widget.extension.clamp(0.0, 240.0);

    // Height is updated on every drag frame via setState; using a plain
    // Container (not AnimatedContainer) so the rail tracks the finger
    // instantly without an animation lag.
    return Container(
      width: 40,
      height: _baseHeight + ext,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Icon(
              widget.locked ? widget.lockIcon : widget.lockOpenIcon,
              key: ValueKey(widget.locked),
              size: 22,
              color: widget.locked ? _green : _gray,
            ),
          ),
          // Chevron at the bottom — fades as drag progresses toward lock
          Opacity(
            opacity: (1 - t * 1.4).clamp(0.0, 1.0),
            child: AnimatedBuilder(
              animation: _hintCtrl,
              builder: (context, _) {
                final bounce = -3.0 * _hintCtrl.value;
                return Transform.translate(
                  offset: Offset(0, bounce),
                  child: Icon(
                    widget.lockArrowIcon,
                    size: 22,
                    color: _gray,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

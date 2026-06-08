import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// A golden, slightly raised button used across the menus.
class OlympusButton extends StatefulWidget {
  const OlympusButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.width,
    this.height = 60,
    this.fontSize = 20,
    this.primary = true,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final double? width;
  final double height;
  final double fontSize;
  final bool primary;
  final bool enabled;

  @override
  State<OlympusButton> createState() => _OlympusButtonState();
}

class _OlympusButtonState extends State<OlympusButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = widget.primary
        ? const [AppColors.goldLight, AppColors.gold, AppColors.goldDark]
        : const [Color(0xFF35507D), Color(0xFF24395E), Color(0xFF152743)];
    final Color textColor =
        widget.primary ? const Color(0xFF3A2706) : Colors.white;
    final double opacity = widget.enabled ? 1 : 0.45;

    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel:
            widget.enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            width: widget.width,
            height: widget.height,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.primary
                    ? const Color(0xFFFFF0C2)
                    : AppColors.gold.withValues(alpha: 0.7),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: textColor, size: widget.fontSize + 4),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      softWrap: false,
                      style: AppTheme.title(
                        widget.fontSize,
                        color: textColor,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round icon button with the same golden styling.
class OlympusIconButton extends StatelessWidget {
  const OlympusIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF35507D), Color(0xFF152743)],
          ),
          border: Border.all(color: AppColors.gold, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.goldLight, size: size * 0.5),
      ),
    );
  }
}

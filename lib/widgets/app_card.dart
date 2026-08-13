import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final bool elevated;

  AppCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.color,
    this.gradient,
    this.radius = 24,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.28)
        : const Color(0xFF0EA5E9).withValues(alpha: 0.10);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? color ?? theme.cardColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: isDark ? 22 : 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}




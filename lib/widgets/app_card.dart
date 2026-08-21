import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final bool elevated;
  final bool outlined;

  const AppCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.color,
    this.gradient,
    this.radius = 24,
    this.elevated = true,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final defaultSurface = isDark
        ? const Color(0xFF111827).withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.82);
    final resolvedColor = gradient == null ? color ?? defaultSurface : null;
    final borderColor = outlined
        ? (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0).withValues(alpha: 0.70))
        : Colors.transparent;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.20)
        : const Color(0xFF0F172A).withValues(alpha: 0.055);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: resolvedColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: isDark ? 22 : 28,
                  spreadRadius: -8,
                  offset: const Offset(0, 16),
                ),
              ]
            : null,
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MenuActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const MenuActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    final radius = BorderRadius.circular(isCompact ? 18 : 22);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: context.gymSurface,
            borderRadius: radius,
            border: Border.all(color: context.gymBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: context.gymIsDark ? 0.24 : 0.07),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Row(
            children: [
              Container(
                width: isCompact ? 42 : 48,
                height: isCompact ? 42 : 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.gymPrimary.withValues(alpha: 0.18),
                      context.gymFitnessAccent.withValues(alpha: context.gymIsDark ? 0.16 : 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
                ),
                child: Icon(icon, color: context.gymPrimary, size: isCompact ? 22 : 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.gymText,
                        fontSize: isCompact ? 16 : 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.gymMutedText, fontSize: isCompact ? 12 : 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.gymMutedText.withValues(alpha: 0.72)),
            ],
          ),
        ),
      ),
    );
  }
}

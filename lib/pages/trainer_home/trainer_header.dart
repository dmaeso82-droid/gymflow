part of '../trainer_home_page.dart';

class _TrainerHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String gymId;
  final VoidCallback onSettings;

  const _TrainerHeader({required this.title, required this.subtitle, required this.gymId, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.44 : 0.64),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: context.gymPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.bolt_rounded, color: context.gymPrimary, size: 25),
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
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.gymMutedText, fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          NotificationsBell(gymId: gymId),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Ajustes',
            style: IconButton.styleFrom(backgroundColor: context.gymSubtleSurface.withValues(alpha: 0.66)),
            onPressed: onSettings,
            icon: Icon(Icons.settings_rounded, color: context.gymPrimary),
          ),
        ],
      ),
    );
  }
}

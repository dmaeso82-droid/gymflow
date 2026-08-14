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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.gymElevatedSurface.withValues(alpha: context.gymIsDark ? 0.86 : 0.98), borderRadius: BorderRadius.circular(26), border: Border.all(color: context.gymBorder)),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('GymFlow Trainer', style: TextStyle(color: context.gymPrimary, fontSize: 13, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, height: 1.0)),
              const SizedBox(height: 6),
              Text(subtitle, style: TextStyle(color: context.gymMutedText, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          NotificationsBell(gymId: gymId),
          const SizedBox(width: 6),
          IconButton.filled(style: IconButton.styleFrom(backgroundColor: context.gymSubtleSurface), onPressed: onSettings, icon: const Icon(Icons.settings)),
        ],
      ),
    );
  }
}

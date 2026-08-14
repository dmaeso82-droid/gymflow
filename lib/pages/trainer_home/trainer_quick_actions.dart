part of '../trainer_home_page.dart';

class TrainerQuickAction {
  final IconData icon;
  final String title;
  final bool priority;
  final VoidCallback onTap;
  const TrainerQuickAction({required this.icon, required this.title, required this.onTap, this.priority = false});
}

class TrainerQuickActionGrid extends StatelessWidget {
  final List<TrainerQuickAction> actions;
  const TrainerQuickActionGrid({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560 ? 3 : 5;
        const spacing = 8.0;
        final sorted = [...actions]..sort((a, b) => b.priority.toString().compareTo(a.priority.toString()));
        final tileWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(spacing: spacing, runSpacing: spacing, children: sorted.map((action) => SizedBox(width: tileWidth, child: TrainerQuickActionTile(action: action))).toList());
      },
    );
  }
}

class TrainerQuickActionTile extends StatelessWidget {
  final TrainerQuickAction action;
  const TrainerQuickActionTile({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    final bg = action.priority ? context.gymPrimary.withValues(alpha: context.gymIsDark ? 0.22 : 0.12) : context.gymSubtleSurface;
    final border = action.priority ? context.gymPrimary.withValues(alpha: 0.34) : context.gymBorder;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: action.onTap,
        child: Ink(
          height: action.priority ? 82 : 76,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: border)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(action.icon, color: action.priority ? context.gymPrimaryStrong : context.gymPrimary, size: action.priority ? 26 : 24),
            const SizedBox(height: 7),
            Text(action.title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
    );
  }
}

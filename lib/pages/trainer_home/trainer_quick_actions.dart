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
    final sorted = [...actions]..sort((a, b) => b.priority.toString().compareTo(a.priority.toString()));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sorted.map((action) => TrainerQuickActionTile(action: action)).toList(),
    );
  }
}

class TrainerQuickActionTile extends StatelessWidget {
  final TrainerQuickAction action;

  const TrainerQuickActionTile({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: action.onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: action.priority
                ? context.gymPrimary.withValues(alpha: context.gymIsDark ? 0.18 : 0.12)
                : context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: context.gymPrimary.withValues(alpha: 0.11),
                  shape: BoxShape.circle,
                ),
                child: Icon(action.icon, color: context.gymPrimary, size: 17),
              ),
              const SizedBox(width: 8),
              Text(
                action.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.gymText, fontSize: 12.5, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

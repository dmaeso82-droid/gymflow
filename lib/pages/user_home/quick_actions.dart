part of '../user_home_page.dart';

class QuickAction {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const QuickAction({required this.icon, required this.title, required this.onTap});
}

class QuickActionGrid extends StatelessWidget {
  final List<QuickAction> actions;

  const QuickActionGrid({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 430 ? 4 : constraints.maxWidth < 720 ? 5 : 6;
        const spacing = 7.0;
        final tileWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions.map((action) => SizedBox(width: tileWidth, child: QuickActionTile(action: action))).toList(),
        );
      },
    );
  }
}

class QuickActionTile extends StatelessWidget {
  final QuickAction action;

  const QuickActionTile({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: action.onTap,
        child: Ink(
          height: 66,
          decoration: BoxDecoration(
            color: context.gymSubtleSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.gymBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, color: context.gymPrimary, size: 21),
              SizedBox(height: 5),
              Text(
                action.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.2, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

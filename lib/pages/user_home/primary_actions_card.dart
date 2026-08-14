part of '../user_home_page.dart';

class _PrimaryActionsCard extends StatelessWidget {
  final List<QuickAction> actions;
  const _PrimaryActionsCard({required this.actions});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      radius: 24,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionTitle(icon: Icons.touch_app_rounded, title: 'Accesos principales'),
        SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 8.0;
            final width = (constraints.maxWidth - spacing) / 2;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: actions.map((action) => SizedBox(width: width, child: _PrimaryActionTile(action: action))).toList(),
            );
          },
        ),
      ]),
    );
  }
}

class _PrimaryActionTile extends StatelessWidget {
  final QuickAction action;
  const _PrimaryActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: action.onTap,
        child: Ink(
          height: 70,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: context.gymIsDark ? 0.24 : 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: context.gymPrimary.withValues(alpha: 0.28))),
          child: Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(15)), child: Icon(action.icon, color: context.gymPrimaryStrong, size: 22)),
            SizedBox(width: 10),
            Expanded(child: Text(action.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900))),
          ]),
        ),
      ),
    );
  }
}

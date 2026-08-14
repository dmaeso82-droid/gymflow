part of '../user_home_page.dart';

class _SecondaryActionsCard extends StatefulWidget {
  final List<QuickAction> actions;
  const _SecondaryActionsCard({required this.actions});

  @override
  State<_SecondaryActionsCard> createState() => _SecondaryActionsCardState();
}

class _SecondaryActionsCardState extends State<_SecondaryActionsCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final visibleActions = expanded ? widget.actions : widget.actions.take(12).toList();
    return AppCard(
      padding: const EdgeInsets.all(12),
      radius: 24,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _SectionTitle(icon: Icons.grid_view_rounded, title: 'Más herramientas')),
          TextButton.icon(
            onPressed: () => setState(() => expanded = !expanded),
            icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(expanded ? 'Menos' : 'Ver más'),
          ),
        ]),
        SizedBox(height: 10),
        QuickActionGrid(actions: visibleActions),
      ]),
    );
  }
}

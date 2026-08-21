part of '../user_home_page.dart';

class _SecondaryActionsCard extends StatefulWidget {
  final List<QuickAction> actions;

  const _SecondaryActionsCard({required this.actions});

  @override
  State<_SecondaryActionsCard> createState() => _SecondaryActionsCardState();
}

class _SecondaryActionsCardState extends State<_SecondaryActionsCard> {
  bool expanded = false;

  List<QuickAction> get visibleActions {
    if (!expanded) return const <QuickAction>[];

    final seen = <String>{};
    return widget.actions.where((action) {
      final key = action.title.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final actions = visibleActions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => setState(() => expanded = !expanded),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: context.gymPrimary.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(Icons.grid_view_rounded, color: context.gymPrimary, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expanded ? 'Todas las herramientas' : 'Más herramientas',
                          style: TextStyle(
                            color: context.gymText,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          expanded ? 'Oculta accesos secundarios' : 'Ranking, progreso, historial y más',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.gymMutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    expanded ? 'Menos' : 'Ver más',
                    style: TextStyle(
                      color: context.gymPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: context.gymPrimary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 10),
          _CompactToolsGrid(actions: actions),
        ],
      ],
    );
  }
}

class _CompactToolsGrid extends StatelessWidget {
  final List<QuickAction> actions;

  const _CompactToolsGrid({required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        final columns = isNarrow ? 2 : 4;
        const spacing = 8.0;
        final width = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions.map((action) {
            return SizedBox(
              width: width,
              child: _CompactToolTile(action: action),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CompactToolTile extends StatelessWidget {
  final QuickAction action;

  const _CompactToolTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.34 : 0.52),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: context.gymPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(action.icon, color: context.gymPrimary, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.gymText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

part of '../user_home_page.dart';

class _PrimaryActionsCard extends StatelessWidget {
  final List<QuickAction> actions;

  const _PrimaryActionsCard({required this.actions});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      radius: 24,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionTitle(icon: Icons.touch_app_rounded, title: 'Accesos principales'),
        const SizedBox(height: 6),
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

  String subtitleFor(String title) {
    switch (title.toLowerCase()) {
      case 'retos':
        return 'Compite y suma puntos';
      case 'chat':
        return 'Mensajes del gym';
      case 'semana':
        return 'Tu resumen semanal';
      case 'comunidad':
        return 'Feed y compañeros';
      default:
        return 'Abrir sección';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: action.onTap,
        child: Ink(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: context.gymPrimary.withValues(alpha: context.gymIsDark ? 0.24 : 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.gymPrimary.withValues(alpha: 0.28)),
          ),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: context.gymFitnessAccent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(action.icon, color: context.gymPrimaryStrong, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(action.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitleFor(action.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 10.5, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

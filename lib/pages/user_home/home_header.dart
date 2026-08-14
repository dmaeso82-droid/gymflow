part of '../user_home_page.dart';

class _HomeHeader extends StatelessWidget {
  final String name;
  final VoidCallback onSettings;

  const _HomeHeader({required this.name, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: context.gymHeroGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.gymFitnessAccent.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.gymFitnessAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.local_fire_department, color: context.gymPrimary, size: 26),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DALAIGYM PERFORMANCE', style: TextStyle(color: context.gymPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                SizedBox(height: 5),
                Text('Hola, $name', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, height: 1.0)),
                SizedBox(height: 5),
                Text('Tu progreso empieza hoy', style: TextStyle(color: context.gymMutedText, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: context.gymSubtleSurface),
            onPressed: onSettings,
            icon: Icon(Icons.settings),
          ),
        ],
      ),
    );
  }
}

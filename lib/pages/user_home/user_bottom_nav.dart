part of '../user_home_page.dart';

class _UserBottomNav extends StatelessWidget {
  final VoidCallback onRutinas;
  final VoidCallback onRetos;
  final VoidCallback onComunidad;
  final VoidCallback onPerfil;

  const _UserBottomNav({
    required this.onRutinas,
    required this.onRetos,
    required this.onComunidad,
    required this.onPerfil,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: context.gymElevatedSurface.withValues(alpha: context.gymIsDark ? 0.96 : 0.98),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.gymBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.34), blurRadius: 22, offset: const Offset(0, 10))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const _NavItem(icon: Icons.home_rounded, label: 'Inicio', active: true),
            _NavItem(icon: Icons.fitness_center, label: 'Rutinas', onTap: onRutinas),
            _NavItem(icon: Icons.emoji_events, label: 'Retos', onTap: onRetos),
            _NavItem(icon: Icons.groups, label: 'Comunidad', onTap: onComunidad),
            _NavItem(icon: Icons.person, label: 'Perfil', onTap: onPerfil),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _NavItem({required this.icon, required this.label, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? context.gymPrimary : context.gymMutedText;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

part of '../user_home_page.dart';

class _UserBottomNav extends StatelessWidget {
  final VoidCallback onRutinas;
  final VoidCallback onProgreso;
  final VoidCallback onComunidad;
  final VoidCallback onPerfil;

  const _UserBottomNav({
    required this.onRutinas,
    required this.onProgreso,
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
          color: context.gymElevatedSurface.withValues(alpha: context.gymIsDark ? 0.92 : 0.96),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.gymIsDark ? 0.30 : 0.12),
              blurRadius: 26,
              spreadRadius: -8,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            const Expanded(child: _NavItem(icon: Icons.home_rounded, label: 'Inicio', active: true)),
            Expanded(child: _NavItem(icon: Icons.fitness_center_rounded, label: 'Rutinas', onTap: onRutinas)),
            Expanded(child: _NavItem(icon: Icons.insights_rounded, label: 'Progreso', onTap: onProgreso)),
            Expanded(child: _NavItem(icon: Icons.groups_rounded, label: 'Comunidad', onTap: onComunidad)),
            Expanded(child: _NavItem(icon: Icons.person_rounded, label: 'Perfil', onTap: onPerfil)),
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
    final activeColor = context.gymPrimary;
    final inactiveColor = context.gymMutedText.withValues(alpha: 0.82);
    final color = active ? activeColor : inactiveColor;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 54,
          padding: EdgeInsets.symmetric(horizontal: active ? 8 : 4, vertical: 5),
          decoration: BoxDecoration(
            color: active ? activeColor.withValues(alpha: context.gymIsDark ? 0.18 : 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: active ? 23 : 21),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: active ? 10.5 : 10,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w800,
                ),
              ),
              if (active) ...[
                const SizedBox(height: 3),
                Container(
                  width: 18,
                  height: 3,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

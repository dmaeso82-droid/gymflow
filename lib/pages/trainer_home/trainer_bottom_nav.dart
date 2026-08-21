part of '../trainer_home_page.dart';

class _TrainerBottomNav extends StatelessWidget {
  final VoidCallback onTraining;
  final VoidCallback onClients;
  final VoidCallback onRoutines;
  final VoidCallback onCommunity;

  const _TrainerBottomNav({required this.onTraining, required this.onClients, required this.onRoutines, required this.onCommunity});

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
            const Expanded(child: _TrainerNavItem(icon: Icons.home_rounded, label: 'Inicio', active: true)),
            Expanded(child: _TrainerNavItem(icon: Icons.self_improvement_rounded, label: 'Entreno', onTap: onTraining)),
            Expanded(child: _TrainerNavItem(icon: Icons.people_rounded, label: 'Clientes', onTap: onClients)),
            Expanded(child: _TrainerNavItem(icon: Icons.fitness_center_rounded, label: 'Rutinas', onTap: onRoutines)),
            Expanded(child: _TrainerNavItem(icon: Icons.groups_rounded, label: 'Muro', onTap: onCommunity)),
          ],
        ),
      ),
    );
  }
}

class _TrainerNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _TrainerNavItem({required this.icon, required this.label, this.active = false, this.onTap});

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
                style: TextStyle(color: color, fontSize: active ? 10.5 : 10, fontWeight: active ? FontWeight.w900 : FontWeight.w800),
              ),
              if (active) ...[
                const SizedBox(height: 3),
                Container(width: 18, height: 3, decoration: BoxDecoration(color: activeColor, borderRadius: BorderRadius.circular(999))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

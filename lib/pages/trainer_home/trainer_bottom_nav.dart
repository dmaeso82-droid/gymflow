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
        decoration: BoxDecoration(color: context.gymElevatedSurface.withValues(alpha: context.gymIsDark ? 0.96 : 0.98), borderRadius: BorderRadius.circular(28), border: Border.all(color: context.gymBorder), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.34), blurRadius: 22, offset: const Offset(0, 10))]),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          const _TrainerNavItem(icon: Icons.home_rounded, label: 'Inicio', active: true),
          _TrainerNavItem(icon: Icons.self_improvement, label: 'Entreno', onTap: onTraining),
          _TrainerNavItem(icon: Icons.people, label: 'Clientes', onTap: onClients),
          _TrainerNavItem(icon: Icons.fitness_center, label: 'Rutinas', onTap: onRoutines),
          _TrainerNavItem(icon: Icons.groups, label: 'Muro', onTap: onCommunity),
        ]),
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
    final color = active ? context.gymPrimary : context.gymMutedText;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

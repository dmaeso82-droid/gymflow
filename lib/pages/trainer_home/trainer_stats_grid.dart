part of '../trainer_home_page.dart';

class TrainerStatsGrid extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> trainersStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> clientsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> routinesStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> goalsStream;
  final VoidCallback onOpenTrainers;
  final VoidCallback onOpenClients;
  final VoidCallback onOpenRoutines;
  final VoidCallback onOpenGoals;
  const TrainerStatsGrid({super.key, required this.trainersStream, required this.clientsStream, required this.routinesStream, required this.goalsStream, required this.onOpenTrainers, required this.onOpenClients, required this.onOpenRoutines, required this.onOpenGoals});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: trainersStream,
      builder: (context, trainersSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: clientsStream,
          builder: (context, clientsSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: routinesStream,
              builder: (context, routinesSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: goalsStream,
                  builder: (context, goalsSnapshot) {
                    final trainersCount = (trainersSnapshot.data?.docs ?? []).where((doc) => doc.data()['active'] != false).length;
                    final clientsCount = clientsSnapshot.data?.docs.length ?? 0;
                    final activeRoutinesCount = (routinesSnapshot.data?.docs ?? []).where((doc) => (doc.data()['status'] ?? 'active').toString() != 'archived').length;
                    final pendingGoalsCount = (goalsSnapshot.data?.docs ?? []).where((doc) => doc.data()['completed'] != true).length;
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        const spacing = 8.0;
                        final width = (constraints.maxWidth - spacing) / 2;
                        return Wrap(spacing: spacing, runSpacing: spacing, children: [
                          SizedBox(width: width, child: TrainerStatTile(icon: Icons.groups, value: trainersCount.toString(), label: 'Entrenadores', onTap: onOpenTrainers)),
                          SizedBox(width: width, child: TrainerStatTile(icon: Icons.people, value: clientsCount.toString(), label: 'Clientes', onTap: onOpenClients)),
                          SizedBox(width: width, child: TrainerStatTile(icon: Icons.playlist_add_check, value: activeRoutinesCount.toString(), label: 'Rutinas', onTap: onOpenRoutines)),
                          SizedBox(width: width, child: TrainerStatTile(icon: Icons.flag, value: pendingGoalsCount.toString(), label: 'Objetivos', onTap: onOpenGoals)),
                        ]);
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class TrainerStatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;
  const TrainerStatTile({super.key, required this.icon, required this.value, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 84,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.gymBorder)),
          child: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: context.gymPrimary, size: 21)),
            const SizedBox(width: 10),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, height: 1.0)),
              const SizedBox(height: 5),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
            ])),
          ]),
        ),
      ),
    );
  }
}

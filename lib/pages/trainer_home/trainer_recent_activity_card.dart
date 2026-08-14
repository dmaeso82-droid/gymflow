part of '../trainer_home_page.dart';

class TrainerRecentActivityCard extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> activityStream;
  const TrainerRecentActivityCard({super.key, required this.activityStream});

  String activityTitle(Map<String, dynamic> data) {
    final user = data['user']?.toString() ?? 'Alguien';
    final target = data['target']?.toString() ?? 'un elemento';
    final type = data['type']?.toString() ?? '';
    if (type == 'client_created') return '$user creó a $target';
    if (type == 'client_updated') return '$user actualizó a $target';
    if (type == 'client_deleted') return '$user eliminó a $target';
    if (type.startsWith('routine_')) return '$user actualizó la rutina $target';
    if (type.startsWith('goal_')) return '$user revisó el objetivo $target';
    if (type.startsWith('measurement_')) return '$user registró medidas de $target';
    return '$user actualizó $target';
  }

  IconData activityIcon(String type) {
    if (type == 'client_deleted') return Icons.person_remove_alt_1_rounded;
    if (type.startsWith('client_')) return Icons.person_rounded;
    if (type.startsWith('routine_')) return Icons.fitness_center_rounded;
    if (type.startsWith('template_')) return Icons.tune_rounded;
    if (type.startsWith('measurement_')) return Icons.monitor_weight_rounded;
    if (type.startsWith('goal_')) return Icons.flag_rounded;
    return Icons.history_rounded;
  }

  Color activityColor(BuildContext context, String type) {
    if (type == 'client_deleted') return Colors.redAccent;
    if (type.startsWith('client_')) return context.gymPrimary;
    if (type.startsWith('routine_')) return context.gymFitnessAccent;
    if (type.startsWith('measurement_')) return Colors.purpleAccent;
    if (type.startsWith('goal_')) return Colors.orangeAccent;
    return context.gymMutedText;
  }

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'Fecha pendiente';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 24,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.history, color: context.gymPrimary), const SizedBox(width: 8), const Text('Actividad reciente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: activityStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator()));
            final activities = snapshot.data?.docs ?? [];
            if (activities.isEmpty) return Text('Todavía no hay actividad registrada.', style: TextStyle(color: context.gymMutedText));
            return Column(
              children: activities.map((doc) {
                final data = doc.data();
                final type = data['type']?.toString() ?? '';
                final color = activityColor(context, type);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.gymBorder)),
                  child: Row(children: [
                    Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(13)), child: Icon(activityIcon(type), color: color, size: 19)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(activityTitle(data), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                    const SizedBox(width: 8),
                    Text(formatDate(data['createdAt']), style: TextStyle(color: context.gymMutedText, fontSize: 11)),
                  ]),
                );
              }).toList(),
            );
          },
        ),
      ]),
    );
  }
}

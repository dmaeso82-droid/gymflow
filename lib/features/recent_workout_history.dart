import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';

class RecentWorkoutHistory extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> logsRef;
  final String userId;

  const RecentWorkoutHistory({
    super.key,
    required this.logsRef,
    required this.userId,
  });

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    }

    return 'Fecha pendiente';
  }

  int timestampSortValue(dynamic value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsRef.where('userId', isEqualTo: userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final logs = [...(snapshot.data?.docs ?? [])];

        logs.sort((a, b) {
          final aDate = timestampSortValue(a.data()['createdAt']);
          final bDate = timestampSortValue(b.data()['createdAt']);
          return bDate.compareTo(aDate);
        });

        final recentLogs = logs.take(20).toList();

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(icon: Icons.history, title: 'Historial reciente'),
              const SizedBox(height: 12),
              if (recentLogs.isEmpty)
                const Text(
                  'Todavía no hay entrenamientos registrados.',
                  style: TextStyle(color: Colors.white70),
                )
              else
                ...recentLogs.map((doc) {
                  final data = doc.data();
                  final exercise = data['exercise']?.toString() ?? 'Ejercicio';
                  final routineTitle = data['routineTitle']?.toString() ?? 'Rutina';
                  final weight = data['weight']?.toString() ?? '-';
                  final reps = data['reps']?.toString() ?? '-';
                  final date = formatDate(data['createdAt']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.monitor_weight, color: Colors.greenAccent),
                      ),
                      title: Text(
                        exercise,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(routineTitle, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                InfoChip(text: '$weight kg'),
                                InfoChip(text: '$reps reps'),
                                InfoChip(text: date),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

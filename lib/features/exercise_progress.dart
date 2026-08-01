import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';

class ExerciseProgress extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> logsRef;
  final String userId;

  const ExerciseProgress({
    super.key,
    required this.logsRef,
    required this.userId,
  });

  int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int timestampSortValue(dynamic value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }

    return 0;
  }

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day/$month/$year';
    }

    return 'Fecha pendiente';
  }

  String signedKg(int value) {
    if (value > 0) return '+$value kg';
    if (value < 0) return '$value kg';
    return '0 kg';
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

        final logs = snapshot.data?.docs ?? [];

        if (logs.isEmpty) {
          return const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(icon: Icons.trending_up, title: 'Evolución por ejercicio'),
                SizedBox(height: 12),
                Text(
                  'Todavía no hay entrenamientos registrados para calcular evolución.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }

        final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> groupedLogs = {};

        for (final doc in logs) {
          final data = doc.data();
          final exercise = data['exercise']?.toString().trim() ?? '';
          if (exercise.isEmpty) continue;
          groupedLogs.putIfAbsent(exercise, () => []).add(doc);
        }

        final progressItems = <Map<String, dynamic>>[];
        groupedLogs.forEach((exercise, docs) {
          docs.sort((a, b) {
            final aDate = timestampSortValue(a.data()['createdAt']);
            final bDate = timestampSortValue(b.data()['createdAt']);
            return aDate.compareTo(bDate);
          });

          final first = docs.first.data();
          final latest = docs.last.data();

          Map<String, dynamic> best = first;
          for (final doc in docs) {
            final data = doc.data();
            final weight = intValue(data['weight']);
            final reps = intValue(data['reps']);

            final bestWeight = intValue(best['weight']);
            final bestReps = intValue(best['reps']);

            if (weight > bestWeight || (weight == bestWeight && reps > bestReps)) {
              best = data;
            }
          }

          final firstWeight = intValue(first['weight']);
          final latestWeight = intValue(latest['weight']);
          final bestWeight = intValue(best['weight']);
          final latestReps = intValue(latest['reps']);
          final bestReps = intValue(best['reps']);
          final weightDelta = latestWeight - firstWeight;

          progressItems.add({
            'exercise': exercise,
            'firstWeight': firstWeight,
            'latestWeight': latestWeight,
            'latestReps': latestReps,
            'bestWeight': bestWeight,
            'bestReps': bestReps,
            'weightDelta': weightDelta,
            'series': docs.length,
            'latestDate': latest['createdAt'],
            'routineTitle': latest['routineTitle']?.toString() ?? 'Rutina',
          });
        });

        progressItems.sort((a, b) {
          final deltaCompare = intValue(b['weightDelta']).compareTo(intValue(a['weightDelta']));
          if (deltaCompare != 0) return deltaCompare;

          final bestCompare = intValue(b['bestWeight']).compareTo(intValue(a['bestWeight']));
          if (bestCompare != 0) return bestCompare;

          return a['exercise'].toString().compareTo(b['exercise'].toString());
        });

        final improvedCount = progressItems.where((item) => intValue(item['weightDelta']) > 0).length;
        final bestProgress = progressItems.isEmpty ? null : progressItems.first;
        final bestProgressText = bestProgress == null
            ? '-'
            : '${bestProgress['exercise']} ${signedKg(intValue(bestProgress['weightDelta']))}';

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(icon: Icons.trending_up, title: 'Evolución por ejercicio'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoChip(text: '$improvedCount ejercicios mejorando'),
                  InfoChip(text: 'Mayor progreso: $bestProgressText'),
                ],
              ),
              const SizedBox(height: 14),
              if (progressItems.isEmpty)
                const Text(
                  'Todavía no hay evolución calculable.',
                  style: TextStyle(color: Colors.white70),
                )
              else
                ...progressItems.take(10).map((item) {
                  final exercise = item['exercise']?.toString() ?? 'Ejercicio';
                  final latestWeight = intValue(item['latestWeight']);
                  final latestReps = intValue(item['latestReps']);
                  final bestWeight = intValue(item['bestWeight']);
                  final bestReps = intValue(item['bestReps']);
                  final weightDelta = intValue(item['weightDelta']);
                  final series = intValue(item['series']);
                  final routineTitle = item['routineTitle']?.toString() ?? 'Rutina';
                  final latestDate = formatDate(item['latestDate']);
                  final isImproving = weightDelta > 0;

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
                          color: (isImproving ? Colors.greenAccent : Colors.white54).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isImproving ? Icons.trending_up : Icons.trending_flat,
                          color: isImproving ? Colors.greenAccent : Colors.white54,
                        ),
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
                                InfoChip(text: 'Actual $latestWeight kg x $latestReps'),
                                InfoChip(text: 'Progreso ${signedKg(weightDelta)}'),
                                InfoChip(text: 'Mejor $bestWeight kg x $bestReps'),
                                InfoChip(text: '$series series'),
                                InfoChip(text: latestDate),
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

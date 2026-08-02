
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';

class PersonalRecords extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> logsRef;
  final String userId;

  const PersonalRecords({
    super.key,
    required this.logsRef,
    required this.userId,
  });

  int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double doubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse((value?.toString() ?? '').replaceAll(',', '.')) ?? 0.0;
  }

  String formatKg(double value) {
    if (value == value.roundToDouble()) return '${value.round()} kg';
    return '${value.toStringAsFixed(1).replaceAll('.', ',')} kg';
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsRef.where('userId', isEqualTo: userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppCard(child: Center(child: CircularProgressIndicator()));
        }

        final logs = snapshot.data?.docs ?? [];
        if (logs.isEmpty) {
          return const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(icon: Icons.emoji_events, title: 'Récords personales'),
                SizedBox(height: 12),
                Text(
                  'Todavía no hay datos suficientes para calcular récords personales.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }

        final records = <String, Map<String, dynamic>>{};
        for (final doc in logs) {
          final data = doc.data();
          final exercise = data['exercise']?.toString().trim() ?? '';
          if (exercise.isEmpty) continue;

          final weight = doubleValue(data['weight']);
          final reps = intValue(data['reps']);
          final createdAt = data['createdAt'];
          final routineTitle = data['routineTitle']?.toString() ?? 'Rutina';
          final current = records[exercise];

          if (current == null ||
              weight > doubleValue(current['weight']) ||
              (weight == doubleValue(current['weight']) && reps > intValue(current['reps']))) {
            records[exercise] = {
              'exercise': exercise,
              'weight': weight,
              'reps': reps,
              'createdAt': createdAt,
              'routineTitle': routineTitle,
              'series': 1,
            };
          } else {
            current['series'] = intValue(current['series']) + 1;
          }
        }

        final recordList = records.values.toList();
        recordList.sort((a, b) {
          final weightCompare = doubleValue(b['weight']).compareTo(doubleValue(a['weight']));
          if (weightCompare != 0) return weightCompare;
          final repsCompare = intValue(b['reps']).compareTo(intValue(a['reps']));
          if (repsCompare != 0) return repsCompare;
          return a['exercise'].toString().compareTo(b['exercise'].toString());
        });

        final bestOverall = recordList.isEmpty ? null : recordList.first;
        final bestOverallText = bestOverall == null
            ? '-'
            : '${formatKg(doubleValue(bestOverall['weight']))} · ${bestOverall['exercise']}';

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(icon: Icons.emoji_events, title: 'Récords personales'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoChip(text: '${logs.length} series registradas'),
                  InfoChip(text: '${recordList.length} ejercicios'),
                  InfoChip(text: 'Mejor marca: $bestOverallText'),
                ],
              ),
              const SizedBox(height: 14),
              if (recordList.isEmpty)
                const Text('Todavía no hay récords calculables.', style: TextStyle(color: Colors.white70))
              else
                ...recordList.take(10).map((record) {
                  final exercise = record['exercise']?.toString() ?? 'Ejercicio';
                  final weight = doubleValue(record['weight']);
                  final reps = intValue(record['reps']);
                  final routineTitle = record['routineTitle']?.toString() ?? 'Rutina';
                  final date = formatDate(record['createdAt']);

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
                          color: Colors.amberAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.workspace_premium, color: Colors.amberAccent),
                      ),
                      title: Text(exercise, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                InfoChip(text: 'PR ${formatKg(weight)}'),
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';

class WeeklySummary extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> logsRef;
  final String filterField;
  final String filterValue;
  final String title;
  final String emptyText;

  const WeeklySummary({
    super.key,
    required this.logsRef,
    required this.filterField,
    required this.filterValue,
    this.title = 'Resumen semanal',
    this.emptyText = 'Todavía no hay entrenamientos registrados esta semana.',
  });

  int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int timestampSortValue(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return 0;
  }

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

  bool isThisWeek(dynamic value) {
    if (value is! Timestamp) return false;

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    final date = value.toDate();

    return !date.isBefore(startOfWeek) && date.isBefore(endOfWeek);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsRef.where(filterField, isEqualTo: filterValue).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final allLogs = [...(snapshot.data?.docs ?? [])];
        final weekLogs = allLogs.where((doc) => isThisWeek(doc.data()['createdAt'])).toList();

        weekLogs.sort((a, b) {
          final aDate = timestampSortValue(a.data()['createdAt']);
          final bDate = timestampSortValue(b.data()['createdAt']);
          return bDate.compareTo(aDate);
        });

        if (weekLogs.isEmpty) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(icon: Icons.calendar_view_week, title: title),
                const SizedBox(height: 12),
                Text(emptyText, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          );
        }

        final exercises = <String>{};
        Map<String, dynamic>? bestRecord;

        for (final doc in weekLogs) {
          final data = doc.data();
          final exercise = data['exercise']?.toString().trim() ?? '';
          final weight = intValue(data['weight']);
          final reps = intValue(data['reps']);

          if (exercise.isNotEmpty) exercises.add(exercise);

          if (bestRecord == null ||
              weight > intValue(bestRecord['weight']) ||
              (weight == intValue(bestRecord['weight']) && reps > intValue(bestRecord['reps']))) {
            bestRecord = data;
          }
        }

        final latest = weekLogs.first.data();
        final latestDate = formatDate(latest['createdAt']);
        final bestExercise = bestRecord?['exercise']?.toString() ?? 'Sin marca';
        final bestWeight = intValue(bestRecord?['weight']);
        final bestReps = intValue(bestRecord?['reps']);

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(icon: Icons.calendar_view_week, title: title),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoChip(text: '${weekLogs.length} series esta semana'),
                  InfoChip(text: '${exercises.length} ejercicios'),
                  InfoChip(text: 'Último: $latestDate'),
                  InfoChip(text: 'Mejor: $bestExercise $bestWeight kg x $bestReps'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/app_formatters.dart';
import '../theme/app_theme.dart';

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

double doubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
  }

int timestampSortValue(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return 0;
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
          return AppCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final allLogs = [...(snapshot.data?.docs ?? [])];
        final weekLogs = allLogs.where((doc) => AppFormatters.isThisWeek(doc.data()['createdAt'])).toList();

        weekLogs.sort((a, b) {
          final aDate = AppFormatters.timestampSortValue(a.data()['createdAt']);
          final bDate = AppFormatters.timestampSortValue(b.data()['createdAt']);
          return bDate.compareTo(aDate);
        });

        if (weekLogs.isEmpty) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(icon: Icons.calendar_view_week, title: title),
                SizedBox(height: 12),
                Text(emptyText, style: TextStyle(color: context.gymMutedText)),
              ],
            ),
          );
        }

        final exercises = <String>{};
        Map<String, dynamic>? bestRecord;
        double weekVolume = 0;

        for (final doc in weekLogs) {
          final data = doc.data();
          final exercise = data['exercise']?.toString().trim() ?? '';
          final weight = AppFormatters.doubleValue(data['weight']);
          final reps = AppFormatters.intValue(data['reps']);
          weekVolume += weight * reps;

          if (exercise.isNotEmpty) exercises.add(exercise);

          if (bestRecord == null ||
              weight > AppFormatters.doubleValue(bestRecord['weight']) ||
              (weight == AppFormatters.doubleValue(bestRecord['weight']) && reps > AppFormatters.intValue(bestRecord['reps']))) {
            bestRecord = data;
          }
        }

        final latest = weekLogs.first.data();
        final latestDate = AppFormatters.formatDate(latest['createdAt']);
        final bestExercise = bestRecord?['exercise']?.toString() ?? 'Sin marca';
        final bestWeight = AppFormatters.formatCompact(AppFormatters.doubleValue(bestRecord?['weight']));
        final bestReps = AppFormatters.intValue(bestRecord?['reps']);

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(icon: Icons.calendar_view_week, title: title),
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoChip(text: '${weekLogs.length} series esta semana'),
                  InfoChip(text: 'Volumen: ${AppFormatters.formatCompact(weekVolume)} kg'),
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




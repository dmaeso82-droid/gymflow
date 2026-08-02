
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';
import 'user_achievements.dart';

class UserDashboard extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;

  const UserDashboard({
    super.key,
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  CollectionReference<Map<String, dynamic>> get routinesRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('routines');

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('workout_logs');

  CollectionReference<Map<String, dynamic>> get goalsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('goals');

  CollectionReference<Map<String, dynamic>> get measurementsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('body_measurements');

  String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String todayName() {
    switch (DateTime.now().weekday) {
      case DateTime.monday:
        return 'Lunes';
      case DateTime.tuesday:
        return 'Martes';
      case DateTime.wednesday:
        return 'Miércoles';
      case DateTime.thursday:
        return 'Jueves';
      case DateTime.friday:
        return 'Viernes';
      case DateTime.saturday:
        return 'Sábado';
      case DateTime.sunday:
        return 'Domingo';
      default:
        return 'Sin día';
    }
  }

  int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

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

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day/$month/$year';
    }
    return 'Sin fecha';
  }

  String formatCompactNumber(double value) {
    if (value == 0) return '-';
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1);
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

  int trainingStreak(List<QueryDocumentSnapshot<Map<String, dynamic>>> logs) {
    final trainingDays = <DateTime>{};

    for (final log in logs) {
      final createdAt = log.data()['createdAt'];
      if (createdAt is! Timestamp) continue;
      final date = createdAt.toDate();
      trainingDays.add(DateTime(date.year, date.month, date.day));
    }

    if (trainingDays.isEmpty) return 0;

    var currentDay = DateTime.now();
    currentDay = DateTime(currentDay.year, currentDay.month, currentDay.day);
    var streak = 0;

    if (!trainingDays.contains(currentDay)) {
      final yesterday = currentDay.subtract(const Duration(days: 1));
      if (trainingDays.contains(yesterday)) {
        currentDay = yesterday;
      } else {
        return 0;
      }
    }

    while (trainingDays.contains(currentDay)) {
      streak++;
      currentDay = currentDay.subtract(const Duration(days: 1));
    }

    return streak;
  }

  Map<String, dynamic>? bestRecord(List<QueryDocumentSnapshot<Map<String, dynamic>>> logs) {
    Map<String, dynamic>? best;

    for (final log in logs) {
      final data = log.data();
      final weight = intValue(data['weight']);
      final reps = intValue(data['reps']);

      if (best == null ||
          weight > intValue(best['weight']) ||
          (weight == intValue(best['weight']) && reps > intValue(best['reps']))) {
        best = data;
      }
    }

    return best;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsRef.where('userId', isEqualTo: userId).snapshots(),
      builder: (context, logsSnapshot) {
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> logs =
            List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(logsSnapshot.data?.docs ?? []);

        logs.sort((a, b) {
          final aDate = timestampSortValue(a.data()['createdAt']);
          final bDate = timestampSortValue(b.data()['createdAt']);
          return bDate.compareTo(aDate);
        });

        final weekLogs = logs.where((log) => isThisWeek(log.data()['createdAt'])).toList();
        final weekExercises = <String>{};
        for (final log in weekLogs) {
          final exercise = log.data()['exercise']?.toString().trim() ?? '';
          if (exercise.isNotEmpty) weekExercises.add(exercise);
        }

        final streak = trainingStreak(logs);
        final best = bestRecord(logs);
        final latestLogDate = logs.isEmpty ? 'Sin entrenos' : formatDate(logs.first.data()['createdAt']);
        final bestExercise = best?['exercise']?.toString() ?? 'Sin marca';
        final bestWeight = best == null ? '-' : '${intValue(best['weight'])} kg';
        final bestReps = best == null ? '-' : '${intValue(best['reps'])} reps';

        return Column(
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${greeting()}, $userName',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tu resumen principal para saber qué toca hoy y cómo vas progresando.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: goalsRef.where('clientEmail', isEqualTo: userEmail.toLowerCase()).snapshots(),
                    builder: (context, goalsSnapshot) {
                      final goals = goalsSnapshot.data?.docs ?? [];
                      final completed = goals.where((goal) => goal.data()['completed'] == true).length;
                      final pending = goals.length - completed;

                      return DashboardMetricGrid(
                        metrics: [
                          DashboardMetric(
                            icon: Icons.local_fire_department,
                            value: '$streak',
                            label: 'Racha',
                            detail: streak == 1 ? 'día seguido' : 'días seguidos',
                            color: Colors.orangeAccent,
                          ),
                          DashboardMetric(
                            icon: Icons.fitness_center,
                            value: '${weekLogs.length}',
                            label: 'Series',
                            detail: 'esta semana',
                            color: Colors.greenAccent,
                          ),
                          DashboardMetric(
                            icon: Icons.flag,
                            value: '$pending',
                            label: 'Objetivos',
                            detail: '$completed completados',
                            color: Colors.lightBlueAccent,
                          ),
                          DashboardMetric(
                            icon: Icons.emoji_events,
                            value: bestWeight,
                            label: 'Mejor marca',
                            detail: best == null ? 'sin datos' : bestExercise,
                            color: Colors.amberAccent,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InfoChip(text: '${weekExercises.length} ejercicios esta semana'),
                      InfoChip(text: 'Último entreno: $latestLogDate'),
                      if (best != null) InfoChip(text: '$bestExercise · $bestReps'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            UserAchievementsPanel(
              gymId: gymId,
              userId: userId,
              userEmail: userEmail,
              compact: true,
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: routinesRef.where('clientEmail', isEqualTo: userEmail.toLowerCase()).snapshots(),
              builder: (context, routinesSnapshot) {
                final routines = routinesSnapshot.data?.docs ?? [];
                final today = todayName();
                final todayRoutines = routines.where((doc) => (doc.data()['day'] ?? '').toString() == today).toList();

                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(icon: Icons.calendar_month, title: 'Entreno de hoy'),
                      const SizedBox(height: 12),
                      if (todayRoutines.isEmpty)
                        Text('$today: descanso o sin rutina asignada.', style: const TextStyle(color: Colors.white70))
                      else
                        ...todayRoutines.map((doc) {
                          final data = doc.data();
                          final exercises = List<dynamic>.from(data['exercises'] ?? []);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF020617),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.play_arrow, color: Colors.greenAccent),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['title']?.toString() ?? 'Rutina',
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          InfoChip(text: '${exercises.length} ejercicios'),
                                          InfoChip(text: today),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: measurementsRef.where('userId', isEqualTo: userId).snapshots(),
              builder: (context, measurementsSnapshot) {
                final measurements = [...(measurementsSnapshot.data?.docs ?? [])];
                measurements.sort((a, b) {
                  final aDate = timestampSortValue(a.data()['createdAt']);
                  final bDate = timestampSortValue(b.data()['createdAt']);
                  return bDate.compareTo(aDate);
                });

                final latest = measurements.isEmpty ? null : measurements.first.data();
                final double bodyWeight = latest == null ? 0.0 : doubleValue(latest['bodyWeight']);
                final double waist = latest == null ? 0.0 : doubleValue(latest['waist']);

                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(icon: Icons.monitor_weight, title: 'Progreso físico actual'),
                      const SizedBox(height: 12),
                      if (latest == null)
                        const Text('Todavía no tienes medidas corporales registradas.', style: TextStyle(color: Colors.white70))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (bodyWeight > 0) InfoChip(text: 'Peso ${formatCompactNumber(bodyWeight)} kg'),
                            if (waist > 0) InfoChip(text: 'Cintura ${formatCompactNumber(waist)} cm'),
                            InfoChip(text: 'Última medida: ${formatDate(latest['createdAt'])}'),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class DashboardMetric {
  final IconData icon;
  final String value;
  final String label;
  final String detail;
  final Color color;

  const DashboardMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.detail,
    required this.color,
  });
}

class DashboardMetricGrid extends StatelessWidget {
  final List<DashboardMetric> metrics;

  const DashboardMetricGrid({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;
        final columns = isNarrow ? 1 : 2;
        final spacing = isNarrow ? 10.0 : 12.0;
        final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics.map((metric) {
            return SizedBox(
              width: itemWidth,
              child: DashboardMetricTile(metric: metric),
            );
          }).toList(),
        );
      },
    );
  }
}

class DashboardMetricTile extends StatelessWidget {
  final DashboardMetric metric;

  const DashboardMetricTile({super.key, required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: metric.color.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: metric.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(metric.icon, color: metric.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(metric.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  metric.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

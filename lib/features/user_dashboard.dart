
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';
import '../pages/user_routines_page.dart';

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

  CollectionReference<Map<String, dynamic>> get routinesRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('routines');
  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('workout_logs');
  CollectionReference<Map<String, dynamic>> get goalsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('goals');
  CollectionReference<Map<String, dynamic>> get measurementsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('body_measurements');

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

  bool isActiveRoutine(Map<String, dynamic> data) {
    return (data['status'] ?? 'active').toString() != 'archived';
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
      final weight = doubleValue(data['weight']);
      final reps = intValue(data['reps']);
      if (best == null || weight > doubleValue(best['weight']) || (weight == doubleValue(best['weight']) && reps > intValue(best['reps']))) {
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
        final logs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(logsSnapshot.data?.docs ?? []);
        logs.sort((a, b) => timestampSortValue(b.data()['createdAt']).compareTo(timestampSortValue(a.data()['createdAt'])));
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
        final bestWeight = best == null ? '-' : '${formatCompactNumber(doubleValue(best['weight']))} kg';
        final bestReps = best == null ? '-' : '${intValue(best['reps'])} reps';

        return Column(
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${greeting()}, $userName', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('Tu resumen principal para saber qué toca hoy y cómo vas progresando.', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.greenAccent.withOpacity(0.28)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.fitness_center, color: Colors.greenAccent),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ENTRENAR AHORA',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Abre tus rutinas activas y registra tus series.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserRoutinesPage(
                                  gymId: gymId,
                                  userId: userId,
                                  userName: userName,
                                  userEmail: userEmail,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Ver mis rutinas'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: goalsRef.where('clientEmail', isEqualTo: userEmail.toLowerCase()).snapshots(),
                    builder: (context, goalsSnapshot) {
                      final goals = goalsSnapshot.data?.docs ?? [];
                      final completed = goals.where((goal) => goal.data()['completed'] == true).length;
                      final pending = goals.length - completed;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          InfoChip(text: 'Racha: $streak días'),
                          InfoChip(text: '${weekLogs.length} series esta semana'),
                          InfoChip(text: '$pending objetivos pendientes'),
                          InfoChip(text: 'Mejor marca: $bestWeight'),
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
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: routinesRef.where('clientEmail', isEqualTo: userEmail.toLowerCase()).snapshots(),
              builder: (context, routinesSnapshot) {
                final routines = (routinesSnapshot.data?.docs ?? [])
                    .where((doc) => isActiveRoutine(doc.data()))
                    .toList();
                final today = todayName();
                final todayRoutines = routines.where((doc) => (doc.data()['day'] ?? '').toString() == today).toList();
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(icon: Icons.calendar_month, title: 'Entreno de hoy'),
                      const SizedBox(height: 12),
                      if (todayRoutines.isEmpty)
                        Text('$today: descanso o sin rutina activa asignada.', style: const TextStyle(color: Colors.white70))
                      else
                        ...todayRoutines.map((doc) {
                          final data = doc.data();
                          final exercises = List<dynamic>.from(data['exercises'] ?? []);
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              InfoChip(text: data['title']?.toString() ?? 'Rutina'),
                              InfoChip(text: '${exercises.length} ejercicios'),
                              InfoChip(text: today),
                            ],
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
                measurements.sort((a, b) => timestampSortValue(b.data()['createdAt']).compareTo(timestampSortValue(a.data()['createdAt'])));
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

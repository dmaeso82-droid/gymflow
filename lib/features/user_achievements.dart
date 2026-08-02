
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';

class AchievementDefinition {
  final IconData icon;
  final String title;
  final String description;
  final int current;
  final int target;
  final Color color;

  const AchievementDefinition({
    required this.icon,
    required this.title,
    required this.description,
    required this.current,
    required this.target,
    required this.color,
  });

  bool get unlocked => current >= target;
  double get progress => target <= 0 ? 0 : (current / target).clamp(0, 1).toDouble();
}

class UserAchievementsPanel extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userEmail;
  final bool compact;

  const UserAchievementsPanel({
    super.key,
    required this.gymId,
    required this.userId,
    required this.userEmail,
    this.compact = false,
  });

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('workout_logs');

  CollectionReference<Map<String, dynamic>> get goalsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('goals');

  int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int timestampSortValue(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return 0;
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

  List<AchievementDefinition> buildAchievements({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> logs,
    required int completedGoals,
  }) {
    final seriesCount = logs.length;
    final streak = trainingStreak(logs);
    final distinctExercises = <String>{};

    for (final log in logs) {
      final exercise = log.data()['exercise']?.toString().trim() ?? '';
      if (exercise.isNotEmpty) distinctExercises.add(exercise);
    }

    return [
      AchievementDefinition(
        icon: Icons.play_circle_fill,
        title: 'Primer entrenamiento',
        description: 'Registra tu primera serie de entrenamiento.',
        current: seriesCount,
        target: 1,
        color: Colors.greenAccent,
      ),
      AchievementDefinition(
        icon: Icons.fitness_center,
        title: '10 series registradas',
        description: 'Acumula 10 series registradas.',
        current: seriesCount,
        target: 10,
        color: Colors.lightBlueAccent,
      ),
      AchievementDefinition(
        icon: Icons.fitness_center,
        title: '50 series registradas',
        description: 'Acumula 50 series registradas.',
        current: seriesCount,
        target: 50,
        color: Colors.purpleAccent,
      ),
      AchievementDefinition(
        icon: Icons.workspace_premium,
        title: '100 series registradas',
        description: 'Acumula 100 series registradas.',
        current: seriesCount,
        target: 100,
        color: Colors.amberAccent,
      ),
      AchievementDefinition(
        icon: Icons.local_fire_department,
        title: 'Racha de 3 días',
        description: 'Entrena durante 3 días seguidos.',
        current: streak,
        target: 3,
        color: Colors.orangeAccent,
      ),
      AchievementDefinition(
        icon: Icons.local_fire_department,
        title: 'Racha de 7 días',
        description: 'Entrena durante 7 días seguidos.',
        current: streak,
        target: 7,
        color: Colors.deepOrangeAccent,
      ),
      AchievementDefinition(
        icon: Icons.whatshot,
        title: 'Racha de 30 días',
        description: 'Entrena durante 30 días seguidos.',
        current: streak,
        target: 30,
        color: Colors.redAccent,
      ),
      AchievementDefinition(
        icon: Icons.flag,
        title: 'Primer objetivo completado',
        description: 'Completa tu primer objetivo asignado.',
        current: completedGoals,
        target: 1,
        color: Colors.cyanAccent,
      ),
      AchievementDefinition(
        icon: Icons.flag_circle,
        title: '5 objetivos completados',
        description: 'Completa 5 objetivos asignados.',
        current: completedGoals,
        target: 5,
        color: Colors.tealAccent,
      ),
      AchievementDefinition(
        icon: Icons.emoji_events,
        title: '10 objetivos completados',
        description: 'Completa 10 objetivos asignados.',
        current: completedGoals,
        target: 10,
        color: Colors.amber,
      ),
      AchievementDefinition(
        icon: Icons.trending_up,
        title: 'Primer ejercicio con marca',
        description: 'Registra marcas en tu primer ejercicio.',
        current: distinctExercises.length,
        target: 1,
        color: Colors.greenAccent,
      ),
      AchievementDefinition(
        icon: Icons.auto_graph,
        title: '10 ejercicios diferentes',
        description: 'Registra marcas en 10 ejercicios diferentes.',
        current: distinctExercises.length,
        target: 10,
        color: Colors.indigoAccent,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsRef.where('userId', isEqualTo: userId).snapshots(),
      builder: (context, logsSnapshot) {
        if (logsSnapshot.connectionState == ConnectionState.waiting) {
          return const AppCard(child: Center(child: CircularProgressIndicator()));
        }

        final logs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(logsSnapshot.data?.docs ?? []);
        logs.sort((a, b) {
          final aDate = timestampSortValue(a.data()['createdAt']);
          final bDate = timestampSortValue(b.data()['createdAt']);
          return bDate.compareTo(aDate);
        });

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: goalsRef.where('clientEmail', isEqualTo: userEmail.toLowerCase()).snapshots(),
          builder: (context, goalsSnapshot) {
            final goals = goalsSnapshot.data?.docs ?? [];
            final completedGoals = goals.where((goal) => goal.data()['completed'] == true).length;
            final achievements = buildAchievements(logs: logs, completedGoals: completedGoals);
            final unlocked = achievements.where((achievement) => achievement.unlocked).toList();
            final locked = achievements.where((achievement) => !achievement.unlocked).toList();
            final visible = compact
                ? [...unlocked.reversed.take(3), ...locked.take(3 - unlocked.reversed.take(3).length)]
                : achievements;

            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(icon: Icons.military_tech, title: 'Logros'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InfoChip(text: '${unlocked.length}/${achievements.length} desbloqueados'),
                      if (locked.isNotEmpty) InfoChip(text: 'Siguiente: ${locked.first.title}'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (visible.isEmpty)
                    const Text('Todavía no hay logros disponibles.', style: TextStyle(color: Colors.white70))
                  else
                    ...visible.map((achievement) => AchievementTile(achievement: achievement, compact: compact)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class AchievementTile extends StatelessWidget {
  final AchievementDefinition achievement;
  final bool compact;

  const AchievementTile({super.key, required this.achievement, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: unlocked ? achievement.color.withOpacity(0.35) : Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (unlocked ? achievement.color : Colors.white54).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              unlocked ? achievement.icon : Icons.lock_outline,
              color: unlocked ? achievement.color : Colors.white54,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: unlocked ? Colors.white : Colors.white70,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 4),
                  Text(achievement.description, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: achievement.progress,
                    minHeight: 7,
                    backgroundColor: Colors.white12,
                    color: unlocked ? achievement.color : Colors.white54,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  unlocked ? 'Desbloqueado' : '${achievement.current}/${achievement.target}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

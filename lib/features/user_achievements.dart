import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../services/achievement_service.dart';
import '../widgets/app_card.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';

class AchievementDefinition {
  final IconData icon;
  final String id;
  final String title;
  final String description;
  final int current;
  final int target;
  final Color color;
  final bool permanentlyUnlocked;

  const AchievementDefinition({
    required this.icon,
    required this.id,
    required this.title,
    required this.description,
    required this.current,
    required this.target,
    required this.color,
    this.permanentlyUnlocked = false,
  });

  bool get unlocked => permanentlyUnlocked || current >= target;
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

  AchievementService get service => AchievementService(
        gymId: gymId,
        userId: userId,
        userName: '',
        userEmail: userEmail,
      );

  CollectionReference<Map<String, dynamic>> get unlockedRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('user_achievements');

  IconData iconFor(String iconKey) {
    switch (iconKey) {
      case 'workout':
        return Icons.play_circle_fill;
      case 'series':
        return Icons.fitness_center;
      case 'volume':
        return Icons.monitor_weight;
      case 'streak':
        return Icons.local_fire_department;
      case 'exercise':
        return Icons.auto_graph;
      case 'trophy':
      default:
        return Icons.emoji_events;
    }
  }

  Color colorFor(String iconKey) {
    switch (iconKey) {
      case 'workout':
        return Colors.greenAccent;
      case 'series':
        return Colors.lightBlueAccent;
      case 'volume':
        return Colors.purpleAccent;
      case 'streak':
        return Colors.orangeAccent;
      case 'exercise':
        return Colors.indigoAccent;
      case 'trophy':
      default:
        return Colors.amberAccent;
    }
  }

  List<AchievementDefinition> buildAchievements({
    required AchievementStats stats,
    required Set<String> unlockedIds,
  }) {
    return automaticAchievementDefinitions.map((definition) {
      return AchievementDefinition(
        id: definition.id,
        icon: iconFor(definition.iconKey),
        title: definition.title,
        description: definition.description,
        current: stats.valueFor(definition.metric),
        target: definition.target,
        color: colorFor(definition.iconKey),
        permanentlyUnlocked: unlockedIds.contains(definition.id),
      );
    }).toList();
  }

  bool isForUser(Map<String, dynamic> data) {
    final storedUserId = data['userId']?.toString() ?? '';
    final storedEmail = (data['userEmail'] ?? '').toString().toLowerCase();
    final normalizedEmail = userEmail.toLowerCase();
    return (userId.isNotEmpty && storedUserId == userId) ||
        (normalizedEmail.isNotEmpty && storedEmail == normalizedEmail);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AchievementStats>(
      future: service.loadStats(),
      builder: (context, statsSnapshot) {
        if (statsSnapshot.connectionState == ConnectionState.waiting) {
          return AppCard(child: Center(child: CircularProgressIndicator()));
        }

        final stats = statsSnapshot.data ?? const AchievementStats(workouts: 0, series: 0, volume: 0, streak: 0, exercises: 0);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: unlockedRef.snapshots(),
          builder: (context, unlockedSnapshot) {
            final unlockedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(unlockedSnapshot.data?.docs ?? [])
                .where((doc) => isForUser(doc.data()))
                .toList();
            final unlockedIds = unlockedDocs.map((doc) => doc.data()['achievementId']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();
            final achievements = buildAchievements(stats: stats, unlockedIds: unlockedIds);
            final unlocked = achievements.where((achievement) => achievement.unlocked).toList();
            final locked = achievements.where((achievement) => !achievement.unlocked).toList();
            final unlockedPreview = unlocked.reversed.take(3).toList();
            final visible = compact
                ? [...unlockedPreview, ...locked.take(3 - unlockedPreview.length)]
                : achievements;

            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(icon: Icons.military_tech, title: 'Logros'),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InfoChip(text: '${unlocked.length}/${achievements.length} desbloqueados'),
                      InfoChip(text: '${stats.workouts} entrenos'),
                      InfoChip(text: '${stats.volume} kg movidos'),
                      if (locked.isNotEmpty) InfoChip(text: 'Siguiente: ${locked.first.title}'),
                    ],
                  ),
                  SizedBox(height: 14),
                  if (visible.isEmpty)
                    Text('Todavía no hay logros disponibles.', style: TextStyle(color: context.gymMutedText))
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
        color: context.gymSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: unlocked ? achievement.color.withValues(alpha: 0.35) : context.gymBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (unlocked ? achievement.color : context.gymMutedText).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              unlocked ? achievement.icon : Icons.lock_outline,
              color: unlocked ? achievement.color : context.gymMutedText,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: unlocked ? Colors.white : context.gymMutedText,
                  ),
                ),
                if (!compact) ...[
                  SizedBox(height: 4),
                  Text(achievement.description, style: TextStyle(color: context.gymMutedText, fontSize: 12)),
                ],
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: achievement.progress,
                    minHeight: 7,
                    backgroundColor: context.gymProgressTrack,
                    color: unlocked ? achievement.color : context.gymMutedText,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  unlocked ? 'Desbloqueado' : '${achievement.current}/${achievement.target}',
                  style: TextStyle(color: context.gymMutedText, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}





import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_formatters.dart';
import '../services/stats_service.dart';
import '../services/points_service.dart';
import '../theme/app_theme.dart';

import '../widgets/app_card.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/physical_progress_summary.dart';
import 'chat_page.dart';

class UserProfilePage extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;
  final String? currentUserId;
  final String? currentUserName;
  final String? currentUserEmail;
  final String currentRole;

  const UserProfilePage({
    super.key,
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.currentUserId,
    this.currentUserName,
    this.currentUserEmail,
    this.currentRole = 'user',
  });

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('workout_logs');

  CollectionReference<Map<String, dynamic>> get challengesRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('challenges');
  CollectionReference<Map<String, dynamic>> get userStatsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('user_stats');
  CollectionReference<Map<String, dynamic>> get leaderboardRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('leaderboard');
  CollectionReference<Map<String, dynamic>> get achievementsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('user_achievements');
  CollectionReference<Map<String, dynamic>> get communityPostsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('community_posts');

double doubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
  }

String formatNumber(num value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

bool belongsToUser(Map<String, dynamic> data) {
    final normalizedEmail = userEmail.trim().toLowerCase();
    final dataUserId = data['userId']?.toString() ?? '';
    final dataEmail = (data['userEmail'] ?? '').toString().toLowerCase();
    if (userId.isNotEmpty && dataUserId == userId) return true;
    if (normalizedEmail.isNotEmpty && dataEmail == normalizedEmail) return true;
    return false;
  }


  Query<Map<String, dynamic>> scopedLogsQuery() {
    if (userId.trim().isNotEmpty) {
      return logsRef.where('userId', isEqualTo: userId.trim());
    }
    final normalizedEmail = userEmail.trim().toLowerCase();
    if (normalizedEmail.isNotEmpty) {
      return logsRef.where('userEmail', isEqualTo: normalizedEmail);
    }
    return logsRef.limit(1);
  }

  UserProfileStats buildStats(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final logs = docs.where((doc) => belongsToUser(doc.data())).toList();
    logs.sort((a, b) => AppFormatters.timestampSortValue(b.data()['createdAt']).compareTo(AppFormatters.timestampSortValue(a.data()['createdAt'])));

    final exercises = <String>{};
    final trainingDays = <DateTime>{};
    final records = <String, Map<String, dynamic>>{};
    double totalVolume = 0;

    for (final doc in logs) {
      final data = doc.data();
      final exercise = data['exercise']?.toString().trim() ?? '';
      final weight = AppFormatters.doubleValue(data['weight']);
      final reps = AppFormatters.intValue(data['reps']);
      totalVolume += weight * reps;
      if (exercise.isNotEmpty) exercises.add(exercise);

      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        final date = createdAt.toDate();
        trainingDays.add(DateTime(date.year, date.month, date.day));
      }

      if (exercise.isNotEmpty) {
        final current = records[exercise];
        if (current == null ||
            weight > AppFormatters.doubleValue(current['weight']) ||
            (weight == AppFormatters.doubleValue(current['weight']) && reps > AppFormatters.intValue(current['reps']))) {
          records[exercise] = {
            'exercise': exercise,
            'weight': weight,
            'reps': reps,
            'createdAt': createdAt,
            'routineTitle': data['routineTitle']?.toString() ?? 'Rutina',
          };
        }
      }
    }

    final recordList = records.values.toList();
    recordList.sort((a, b) {
      final weightCompare = AppFormatters.doubleValue(b['weight']).compareTo(AppFormatters.doubleValue(a['weight']));
      if (weightCompare != 0) return weightCompare;
      return AppFormatters.intValue(b['reps']).compareTo(AppFormatters.intValue(a['reps']));
    });

    return UserProfileStats(
      logs: logs,
      trainingDays: trainingDays,
      exercises: exercises,
      records: recordList,
      totalVolume: totalVolume,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    final displayName = userName.trim().isEmpty ? 'Usuario' : userName.trim();
    final normalizedEmail = userEmail.trim().toLowerCase();
    final authUser = FirebaseAuth.instance.currentUser;
    final effectiveCurrentUserId = (currentUserId ?? '').trim().isNotEmpty ? currentUserId!.trim() : (authUser?.uid ?? '');
    final effectiveCurrentUserEmail = (currentUserEmail ?? '').trim().isNotEmpty
        ? currentUserEmail!.trim().toLowerCase()
        : (authUser?.email ?? '').trim().toLowerCase();
    final effectiveCurrentUserName = (currentUserName ?? '').trim().isNotEmpty
        ? currentUserName!.trim()
        : ((authUser?.displayName ?? '').trim().isNotEmpty ? authUser!.displayName!.trim() : 'Usuario');
    final isOwnProfile = (userId.trim().isNotEmpty && effectiveCurrentUserId == userId.trim()) ||
        (normalizedEmail.isNotEmpty && effectiveCurrentUserEmail == normalizedEmail);
    final canMessageProfile = effectiveCurrentUserId.isNotEmpty && !isOwnProfile;
    final statsDocId = StatsService(gymId: gymId).statsDocId(userId: userId, userEmail: userEmail);
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userStatsRef.doc(statsDocId).snapshots(),
          builder: (context, statsSnapshot) {
            final statsData = statsSnapshot.data?.data() ?? <String, dynamic>{};
            final workouts = AppFormatters.intValue(statsData['workouts']);
            final series = AppFormatters.intValue(statsData['series']);
            final volume = AppFormatters.doubleValue(statsData['volume']);
            final records = AppFormatters.intValue(statsData['recordCount']);
            final exerciseCount = AppFormatters.intValue(statsData['exerciseCount']);
            final lastExercise = statsData['lastExercise']?.toString() ?? '';
            final lastWorkout = statsData['lastWorkout'];
            final streak = AppFormatters.intValue(statsData['currentStreak']);
            final photos = AppFormatters.intValue(statsData['photos']);
            final transformations = AppFormatters.intValue(statsData['transformations']);
            final statsPoints = AppFormatters.intValue(statsData['points']);
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: scopedLogsQuery().limit(12).snapshots(),
              builder: (context, snapshot) {
                final stats = buildStats(snapshot.data?.docs ?? []);
                final bestRecord = stats.records.isEmpty ? null : stats.records.first;
                final latestLog = stats.logs.isEmpty ? null : stats.logs.first.data();
                return ListView(
                  padding: EdgeInsets.all(isCompact ? 12 : 16),
                  children: [
                    AppCard(
                      child: Row(
                        children: [
                          ProfileAvatar(name: displayName, size: isCompact ? 64 : 74),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: isCompact ? 22 : 24, fontWeight: FontWeight.w900)),
                                if (normalizedEmail.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(normalizedEmail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText)),
                                ],
                                const SizedBox(height: 8),
                                Text('DalaiGym', style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w800)),
                                if (canMessageProfile) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: isCompact ? double.infinity : null,
                                    child: FilledButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatPage(
                                          gymId: gymId,
                                          currentUserId: effectiveCurrentUserId,
                                          currentUserName: effectiveCurrentUserName,
                                          currentUserEmail: effectiveCurrentUserEmail,
                                          currentRole: currentRole,
                                          otherUserId: userId,
                                          otherUserName: displayName,
                                          otherUserEmail: normalizedEmail,
                                          otherRole: 'user',
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(Icons.chat_bubble_outline),
                                    label: const Text('Enviar mensaje'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AdvancedProfileSummary(
                      leaderboardRef: leaderboardRef,
                      achievementsRef: achievementsRef,
                      communityPostsRef: communityPostsRef,
                      leaderboardDocId: statsDocId,
                      userId: userId,
                      userEmail: normalizedEmail,
                      streak: streak,
                      photos: photos,
                      transformations: transformations,
                      statsPoints: statsPoints,
                    ),
                    const SizedBox(height: 12),
                    _ProfileRankingPositions(
                      leaderboardRef: leaderboardRef,
                      userId: userId,
                      userEmail: normalizedEmail,
                    ),
                    const SizedBox(height: 12),
                    _RecentAchievementsCard(
                      achievementsRef: achievementsRef,
                      userId: userId,
                      userEmail: normalizedEmail,
                    ),
                    const SizedBox(height: 12),
                    _SharedTransformationsCard(
                      communityPostsRef: communityPostsRef,
                      userId: userId,
                      userEmail: normalizedEmail,
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth < 560 ? 2 : 4;
                          const spacing = 8.0;
                          final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.fitness_center, value: workouts.toString(), label: 'Entrenos')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.list_alt, value: series.toString(), label: 'Series')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.monitor_weight, value: '${AppFormatters.formatNumber(volume)} kg', label: 'Volumen')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.workspace_premium, value: records > 0 ? records.toString() : exerciseCount.toString(), label: records > 0 ? 'Récords' : 'Ejercicios')),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    PhysicalProgressSummary(gymId: gymId, userId: userId, userEmail: normalizedEmail, emptyText: 'Todavía no hay medidas corporales registradas para este usuario.'),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeader(icon: Icons.emoji_events, title: 'Mejor marca'),
                          const SizedBox(height: 10),
                          if (bestRecord == null && lastExercise.isEmpty)
                            Text('Todavía no hay marcas registradas.', style: TextStyle(color: context.gymMutedText))
                          else if (bestRecord != null)
                            Row(
                              children: [
                                Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.amberAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.workspace_premium, color: Colors.amberAccent)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(bestRecord['exercise']?.toString() ?? 'Ejercicio', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 4),
                                    Text('${AppFormatters.formatNumber(AppFormatters.doubleValue(bestRecord['weight']))} kg x ${AppFormatters.intValue(bestRecord['reps'])} reps', style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w800)),
                                  ]),
                                ),
                              ],
                            )
                          else
                            Text(lastExercise, style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeader(icon: Icons.history, title: 'Actividad reciente'),
                          const SizedBox(height: 10),
                          if (latestLog == null && lastWorkout == null)
                            Text('Todavía no hay entrenamientos registrados.', style: TextStyle(color: context.gymMutedText))
                          else if (stats.logs.isEmpty)
                            Text('Último entreno: ${AppFormatters.formatDate(lastWorkout)}', style: TextStyle(color: context.gymMutedText))
                          else
                            Column(
                              children: stats.logs.take(5).map((doc) {
                                final data = doc.data();
                                final exercise = data['exercise']?.toString() ?? 'Ejercicio';
                                final routine = data['routineTitle']?.toString() ?? 'Rutina';
                                final weight = AppFormatters.formatNumber(AppFormatters.doubleValue(data['weight']));
                                final reps = AppFormatters.intValue(data['reps']);
                                final date = AppFormatters.formatDate(data['createdAt']);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.gymBorder)),
                                  child: Row(children: [
                                    Icon(Icons.analytics, color: context.gymPrimary, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(exercise, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 3),
                                      Text('$weight kg · $reps reps · $date', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12)),
                                      Text(routine, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText.withValues(alpha: 0.70), fontSize: 11)),
                                    ])),
                                  ]),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeader(icon: Icons.workspace_premium, title: 'Resumen de progreso'),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            _ProfileChip(text: '$workouts entrenos'),
                            _ProfileChip(text: '$series series'),
                            _ProfileChip(text: '${AppFormatters.formatNumber(volume)} kg'),
                            if (exerciseCount > 0) _ProfileChip(text: '$exerciseCount ejercicios'),
                          ]),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

}

class _AdvancedProfileSummary extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> leaderboardRef;
  final CollectionReference<Map<String, dynamic>> achievementsRef;
  final CollectionReference<Map<String, dynamic>> communityPostsRef;
  final String leaderboardDocId;
  final String userId;
  final String userEmail;
  final int streak;
  final int photos;
  final int transformations;
  final int statsPoints;

  const _AdvancedProfileSummary({
    required this.leaderboardRef,
    required this.achievementsRef,
    required this.communityPostsRef,
    required this.leaderboardDocId,
    required this.userId,
    required this.userEmail,
    required this.streak,
    required this.photos,
    required this.transformations,
    required this.statsPoints,
  });

  Query<Map<String, dynamic>> userScopedQuery(CollectionReference<Map<String, dynamic>> ref) {
    if (userId.trim().isNotEmpty) {
      return ref.where('userId', isEqualTo: userId.trim());
    }
    return ref.where('userEmail', isEqualTo: userEmail.trim().toLowerCase());
  }

  Query<Map<String, dynamic>> transformationsQuery() {
    final base = communityPostsRef.where('type', isEqualTo: 'transformation_post');
    if (userId.trim().isNotEmpty) {
      return base.where('userId', isEqualTo: userId.trim());
    }
    return base.where('userEmail', isEqualTo: userEmail.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: leaderboardRef.doc(leaderboardDocId).snapshots(),
      builder: (context, leaderboardSnapshot) {
        final leaderboard = leaderboardSnapshot.data?.data() ?? <String, dynamic>{};
        final allTimePoints = AppFormatters.intValue(leaderboard['allTimePoints']);
        final monthlyPoints = AppFormatters.intValue(leaderboard['monthlyPoints']);
        final yearlyPoints = AppFormatters.intValue(leaderboard['yearlyPoints']);
        final points = allTimePoints > 0 ? allTimePoints : statsPoints;
        final prestige = prestigeForPoints(points);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: userScopedQuery(achievementsRef).snapshots(),
          builder: (context, achievementSnapshot) {
            final achievementCount = achievementSnapshot.data?.docs.length ?? 0;
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: transformationsQuery().snapshots(),
              builder: (context, transformationSnapshot) {
                final transformationCount = transformationSnapshot.data?.docs.length ?? transformations;
                final prestigeTitle = prestigeTitleForStats(
                  points: points,
                  bestStreak: streak,
                  achievements: achievementCount,
                  transformations: transformationCount,
                );
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(icon: Icons.auto_awesome, title: 'Perfil DalaiGym'),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth < 560 ? 2 : 3;
                          const spacing = 8.0;
                          final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.emoji_events, value: '$points', label: 'Puntos')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.military_tech, value: prestige.label, label: 'Nivel')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.auto_awesome, value: prestigeTitle.label, label: 'Título')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.local_fire_department, value: '$streak', label: 'Racha')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.workspace_premium, value: '$achievementCount', label: 'Logros')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.photo_library, value: '$photos', label: 'Fotos')),
                              SizedBox(width: width, child: _ProfileMetric(icon: Icons.compare, value: '$transformationCount', label: 'Cambios')),
                            ],
                          );
                        },
                      ),
                      if (monthlyPoints > 0 || yearlyPoints > 0) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ProfileChip(text: '$monthlyPoints pts este mes'),
                            _ProfileChip(text: '$yearlyPoints pts este año'),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ProfileRankingPositions extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> leaderboardRef;
  final String userId;
  final String userEmail;

  const _ProfileRankingPositions({
    required this.leaderboardRef,
    required this.userId,
    required this.userEmail,
  });

  bool isCurrentUser(Map<String, dynamic> data) {
    final dataUserId = data['userId']?.toString() ?? '';
    final dataEmail = (data['userEmail'] ?? '').toString().toLowerCase();
    final normalizedEmail = userEmail.trim().toLowerCase();
    return (userId.trim().isNotEmpty && dataUserId == userId.trim()) ||
        (normalizedEmail.isNotEmpty && dataEmail == normalizedEmail);
  }

  int positionFor(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, String field) {
    final entries = docs.where((doc) => AppFormatters.intValue(doc.data()[field]) > 0).toList();
    entries.sort((a, b) => AppFormatters.intValue(b.data()[field]).compareTo(AppFormatters.intValue(a.data()[field])));
    final index = entries.indexWhere((doc) => isCurrentUser(doc.data()));
    return index < 0 ? 0 : index + 1;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: leaderboardRef.snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final monthly = positionFor(docs, 'monthlyPoints');
        final yearly = positionFor(docs, 'yearlyPoints');
        final allTime = positionFor(docs, 'allTimePoints');
        if (monthly == 0 && yearly == 0 && allTime == 0) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(icon: Icons.leaderboard, title: 'Posición en rankings'),
                const SizedBox(height: 8),
                Text('Todavía no hay puntos suficientes para calcular posición en ranking.', style: TextStyle(color: context.gymMutedText)),
              ],
            ),
          );
        }
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(icon: Icons.leaderboard, title: 'Posición en rankings'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (monthly > 0) _ProfileChip(text: '#$monthly mensual'),
                  if (yearly > 0) _ProfileChip(text: '#$yearly anual'),
                  if (allTime > 0) _ProfileChip(text: '#$allTime histórico'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentAchievementsCard extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> achievementsRef;
  final String userId;
  final String userEmail;

  const _RecentAchievementsCard({
    required this.achievementsRef,
    required this.userId,
    required this.userEmail,
  });

  Query<Map<String, dynamic>> scopedQuery() {
    if (userId.trim().isNotEmpty) return achievementsRef.where('userId', isEqualTo: userId.trim());
    return achievementsRef.where('userEmail', isEqualTo: userEmail.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: scopedQuery().snapshots(),
      builder: (context, snapshot) {
        final achievements = (snapshot.data?.docs ?? []).toList();
        achievements.sort((a, b) => AppFormatters.timestampSortValue(b.data()['unlockedAt']).compareTo(AppFormatters.timestampSortValue(a.data()['unlockedAt'])));
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(icon: Icons.workspace_premium, title: 'Últimos logros'),
              const SizedBox(height: 10),
              if (achievements.isEmpty)
                Text('Todavía no hay logros desbloqueados.', style: TextStyle(color: context.gymMutedText))
              else
                Column(
                  children: achievements.take(4).map((doc) {
                    final data = doc.data();
                    final title = data['title']?.toString() ?? 'Logro';
                    final description = data['description']?.toString() ?? '';
                    final date = AppFormatters.formatDate(data['unlockedAt'] ?? data['createdAt']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.gymBorder)),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: Colors.amberAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.emoji_events, color: Colors.amberAccent),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900)),
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(description, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12)),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(date, style: TextStyle(color: context.gymMutedText, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SharedTransformationsCard extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> communityPostsRef;
  final String userId;
  final String userEmail;

  const _SharedTransformationsCard({
    required this.communityPostsRef,
    required this.userId,
    required this.userEmail,
  });

  Query<Map<String, dynamic>> scopedQuery() {
    final base = communityPostsRef.where('type', isEqualTo: 'transformation_post');
    if (userId.trim().isNotEmpty) return base.where('userId', isEqualTo: userId.trim());
    return base.where('userEmail', isEqualTo: userEmail.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: scopedQuery().snapshots(),
      builder: (context, snapshot) {
        final posts = (snapshot.data?.docs ?? []).toList();
        posts.sort((a, b) => AppFormatters.timestampSortValue(b.data()['createdAt']).compareTo(AppFormatters.timestampSortValue(a.data()['createdAt'])));
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(icon: Icons.compare, title: 'Transformaciones compartidas'),
              const SizedBox(height: 10),
              if (posts.isEmpty)
                Text('Todavía no hay transformaciones compartidas.', style: TextStyle(color: context.gymMutedText))
              else
                SizedBox(
                  height: 178,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: posts.take(6).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final data = posts[index].data();
                      final before = data['beforeImageUrl']?.toString() ?? '';
                      final after = data['afterImageUrl']?.toString() ?? '';
                      final date = AppFormatters.formatDate(data['createdAt']);
                      return Container(
                        width: 210,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.gymBorder)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text('ANTES', style: TextStyle(color: context.gymPrimary, fontSize: 11, fontWeight: FontWeight.w900))),
                                Expanded(child: Text('DESPUÉS', textAlign: TextAlign.right, style: TextStyle(color: context.gymFitnessAccent, fontSize: 11, fontWeight: FontWeight.w900))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: _TransformationThumb(imageUrl: before)),
                                  const SizedBox(width: 6),
                                  Expanded(child: _TransformationThumb(imageUrl: after)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(date, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TransformationThumb extends StatelessWidget {
  final String imageUrl;

  const _TransformationThumb({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imageUrl.isEmpty
          ? Container(color: context.gymProgressTrack, alignment: Alignment.center, child: Icon(Icons.photo_outlined, color: context.gymMutedText))
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => Container(color: context.gymProgressTrack, alignment: Alignment.center, child: Icon(Icons.broken_image, color: context.gymMutedText)),
            ),
    );
  }
}

class UserProfileStats {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> logs;
  final Set<DateTime> trainingDays;
  final Set<String> exercises;
  final List<Map<String, dynamic>> records;
  final double totalVolume;

  const UserProfileStats({
    required this.logs,
    required this.trainingDays,
    required this.exercises,
    required this.records,
    required this.totalVolume,
  });
}

class _ProfileMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _ProfileMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.gymBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.gymPrimary, size: 20),
          SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 2),
          Text(label, style: TextStyle(color: context.gymMutedText, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.gymPrimary, size: 20),
        SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final String text;

  const _ProfileChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: context.gymFitnessAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.gymFitnessAccent.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(color: context.gymPrimary, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}




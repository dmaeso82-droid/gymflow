
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

part 'user_profile/advanced_profile_summary.dart';
part 'user_profile/profile_ranking_positions.dart';
part 'user_profile/recent_achievements_card.dart';
part 'user_profile/shared_transformations_card.dart';
part 'user_profile/user_profile_stats.dart';
part 'user_profile/profile_widgets.dart';
part 'user_profile/personal_hall_of_fame_card.dart';

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
            final bestStreak = AppFormatters.intValue(statsData['bestStreak']);
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
                    _PersonalHallOfFameCard(
                      leaderboardRef: leaderboardRef,
                      achievementsRef: achievementsRef,
                      communityPostsRef: communityPostsRef,
                      leaderboardDocId: statsDocId,
                      userId: userId,
                      userEmail: normalizedEmail,
                      points: statsPoints,
                      workouts: workouts,
                      bestStreak: bestStreak > streak ? bestStreak : streak,
                      records: records,
                      exerciseCount: exerciseCount,
                      transformations: transformations,
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

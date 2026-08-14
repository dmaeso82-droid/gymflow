import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/app_formatters.dart';
import '../services/stats_service.dart';
import '../services/points_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../pages/user_routines_page.dart';
import '../pages/rankings_page.dart';
import '../pages/progress_photos_page.dart';

part 'dashboard/premium_identity_card.dart';
part 'dashboard/hero_summary_widgets.dart';
part 'dashboard/personal_ranking_preview.dart';
part 'dashboard/physical_preview.dart';
part 'dashboard/top_ranking_preview.dart';

DateTime gymStartOfCurrentWeek() {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  return startOfToday.subtract(Duration(days: now.weekday - DateTime.monday));
}

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

  CollectionReference<Map<String, dynamic>> get logsRef =>
      FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('workout_logs');
  CollectionReference<Map<String, dynamic>> get goalsRef =>
      FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('goals');
  CollectionReference<Map<String, dynamic>> get measurementsRef =>
      FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('body_measurements');
  CollectionReference<Map<String, dynamic>> get progressPhotosRef =>
      FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('progress_photos');
  CollectionReference<Map<String, dynamic>> get userStatsRef =>
      FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('user_stats');
  CollectionReference<Map<String, dynamic>> get rankingStatsRef =>
      FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('ranking_stats');
  CollectionReference<Map<String, dynamic>> get leaderboardRef =>
      FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('leaderboard');
  CollectionReference<Map<String, dynamic>> get achievementsRef =>
      FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('user_achievements');

double doubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
  }

String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
    return 'Sin fecha';
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

  bool isPreviousWeek(dynamic value) {
    if (value is! Timestamp) return false;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final startPreviousWeek = startOfWeek.subtract(const Duration(days: 7));
    final date = value.toDate();
    return !date.isBefore(startPreviousWeek) && date.isBefore(startOfWeek);
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
      final weight = AppFormatters.doubleValue(data['weight']);
      final reps = AppFormatters.intValue(data['reps']);
      if (best == null || weight > AppFormatters.doubleValue(best['weight']) || (weight == AppFormatters.doubleValue(best['weight']) && reps > AppFormatters.intValue(best['reps']))) {
        best = data;
      }
    }
    return best;
  }

  int percentChange(int current, int previous) {
    if (previous <= 0) return current > 0 ? 100 : 0;
    return (((current - previous) / previous) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final statsDocId = StatsService(gymId: gymId).statsDocId(userId: userId, userEmail: userEmail);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStatsRef.doc(statsDocId).snapshots(),
      builder: (context, statsSnapshot) {
        if (statsSnapshot.hasError) {
          return AppCard(
            child: Text('No se han podido cargar tus estadísticas.', style: TextStyle(color: context.gymMutedText)),
          );
        }
        final stats = statsSnapshot.data?.data() ?? <String, dynamic>{};
        final streak = AppFormatters.intValue(stats['currentStreak']);
        final totalSeries = AppFormatters.intValue(stats['series']);
        final totalWorkouts = AppFormatters.intValue(stats['workouts']);
        final exerciseCount = AppFormatters.intValue(stats['exerciseCount']);
        final totalVolume = AppFormatters.doubleValue(stats['volume']);
        final totalPoints = AppFormatters.intValue(stats['points']);
        final latestLogDate = stats['lastWorkout'] == null ? 'Sin entreno' : AppFormatters.formatDate(stats['lastWorkout']);
        final lastExercise = stats['lastExercise']?.toString() ?? '';
        final lastRoutineTitle = stats['lastRoutineTitle']?.toString() ?? '';

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: rankingStatsRef.doc(statsDocId).snapshots(),
          builder: (context, rankingSnapshot) {
            final ranking = rankingSnapshot.data?.data() ?? <String, dynamic>{};
            final weeklySeries = AppFormatters.intValue(ranking['weeklySeries']);
            final weeklyWorkouts = AppFormatters.intValue(ranking['weeklyWorkouts']);
            final weeklyVolume = AppFormatters.doubleValue(ranking['weeklyVolume']);
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: goalsRef.where('clientEmail', isEqualTo: userEmail.toLowerCase()).snapshots(),
              builder: (context, goalsSnapshot) {
                final goals = goalsSnapshot.data?.docs ?? [];
                final completed = goals.where((goal) => goal.data()['completed'] == true).length;
                final pending = goals.length - completed;
                final bestWeight = totalVolume > 0 ? '${AppFormatters.formatCompact(totalVolume)} kg' : '-';
                return Column(
                  children: [
                    _CompactHero(
                      streak: streak,
                      latestLogDate: latestLogDate,
                      weekSeries: weeklySeries > 0 ? weeklySeries : totalSeries,
                      trendPercent: 0,
                      onTrain: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserRoutinesPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _PremiumIdentityCard(
                      leaderboardRef: leaderboardRef,
                      achievementsRef: achievementsRef,
                      statsDocId: statsDocId,
                      userId: userId,
                      userEmail: userEmail,
                      userName: userName,
                      currentStreak: streak,
                    ),
                    const SizedBox(height: 10),
                    _WeekSummaryCard(
                      weekSeries: weeklySeries > 0 ? weeklySeries : totalSeries,
                      previousSeries: 0,
                      weekExercises: exerciseCount,
                      previousExercises: 0,
                      bestWeight: bestWeight,
                      pendingGoals: pending,
                      completedGoals: completed,
                    ),
                    const SizedBox(height: 10),
                    if (lastExercise.isNotEmpty)
                      _HighlightPill(icon: Icons.fitness_center, text: lastRoutineTitle.isEmpty ? lastExercise : '$lastExercise · $lastRoutineTitle')
                    else
                      _HighlightPill(icon: Icons.workspace_premium, text: totalWorkouts > 0 ? '$totalWorkouts entrenos · $totalSeries series' : 'Registra tu primer entreno'),
                    const SizedBox(height: 10),
                    _PersonalRankingPreview(
                      logsRef: logsRef,
                      currentUserId: userId,
                      currentUserEmail: userEmail,
                      currentUserName: userName,
                      gymId: gymId,
                    ),
                    const SizedBox(height: 10),
                    _PhysicalPreview(  
                      gymId: gymId,  
                      userId: userId,  
                      userName: userName,  
                      userEmail: userEmail,  
                      measurementsRef: measurementsRef,  
                      progressPhotosRef: progressPhotosRef,  
                      totalWorkouts: totalWorkouts,  
                      totalPoints: totalPoints,  
                      formatDate: AppFormatters.formatDate,  
                      doubleValue: AppFormatters.doubleValue,  
                      formatCompactNumber: AppFormatters.formatCompact,  
                      timestampSortValue: AppFormatters.timestampSortValue,  
                    ),
                    if (weeklyWorkouts > 0 || weeklyVolume > 0) ...[
                      const SizedBox(height: 10),
                      _HighlightPill(icon: Icons.insights, text: 'Semana actual: $weeklyWorkouts entrenos · ${AppFormatters.formatCompact(weeklyVolume)} kg'),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

}


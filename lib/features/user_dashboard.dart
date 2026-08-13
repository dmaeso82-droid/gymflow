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

class _PremiumIdentityCard extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> leaderboardRef;
  final CollectionReference<Map<String, dynamic>> achievementsRef;
  final String statsDocId;
  final String userId;
  final String userEmail;
  final String userName;
  final int currentStreak;

  const _PremiumIdentityCard({
    required this.leaderboardRef,
    required this.achievementsRef,
    required this.statsDocId,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.currentStreak,
  });

  int nextLevelTarget(int points) {
    if (points < 500) return 500;
    if (points < 1000) return 1000;
    if (points < 2500) return 2500;
    if (points < 5000) return 5000;
    if (points < 10000) return 10000;
    return points;
  }

  String nextLevelName(int points) {
    if (points < 500) return 'Plata';
    if (points < 1000) return 'Oro';
    if (points < 2500) return 'Platino';
    if (points < 5000) return 'Diamante';
    if (points < 10000) return 'Leyenda';
    return 'Nivel máximo';
  }

  Query<Map<String, dynamic>> achievementsQuery() {
    if (userId.trim().isNotEmpty) return achievementsRef.where('userId', isEqualTo: userId.trim());
    return achievementsRef.where('userEmail', isEqualTo: userEmail.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: leaderboardRef.doc(statsDocId).snapshots(),
      builder: (context, leaderboardSnapshot) {
        final leaderboard = leaderboardSnapshot.data?.data() ?? <String, dynamic>{};
        final points = AppFormatters.intValue(leaderboard['allTimePoints']);
        final prestige = prestigeForPoints(points);
        final title = prestigeTitleForStats(points: points, bestStreak: currentStreak);
        final target = nextLevelTarget(points);
        final remaining = target > points ? target - points : 0;
        final progress = target > 0 ? (points / target).clamp(0.0, 1.0) : 1.0;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: achievementsQuery().snapshots(),
          builder: (context, achievementSnapshot) {
            final achievementDocs = [...(achievementSnapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])];
            achievementDocs.sort((a, b) => AppFormatters.timestampSortValue(b.data()['unlockedAt'] ?? b.data()['createdAt']).compareTo(AppFormatters.timestampSortValue(a.data()['unlockedAt'] ?? a.data()['createdAt'])));
            final latestAchievement = achievementDocs.isEmpty ? null : achievementDocs.first.data();
            final latestTitle = latestAchievement?['title']?.toString() ?? 'Desbloquea tu próximo logro';
            return AppCard(
              padding: const EdgeInsets.all(14),
              radius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: Colors.amberAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.auto_awesome, color: Colors.amberAccent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${prestige.label} · ${title.label}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontSize: 18, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            Text('$points puntos históricos · $currentStreak días de racha', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.gymBorder)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flag, color: context.gymFitnessAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(remaining > 0 ? 'Próximo nivel: ${nextLevelName(points)}' : 'Nivel máximo alcanzado', style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900))),
                            Text(remaining > 0 ? '$remaining pts' : 'Top', style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: context.gymProgressTrack, valueColor: AlwaysStoppedAnimation<Color>(context.gymFitnessAccent)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.workspace_premium, color: context.gymFitnessAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Último logro: $latestTitle', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w800))),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CompactHero extends StatelessWidget {
  final int streak;
  final String latestLogDate;
  final int weekSeries;
  final int trendPercent;
  final VoidCallback onTrain;

  const _CompactHero({
    required this.streak,
    required this.latestLogDate,
    required this.weekSeries,
    required this.trendPercent,
    required this.onTrain,
  });

  @override
  Widget build(BuildContext context) {
    final trendText = trendPercent >= 0 ? '+$trendPercent%' : '$trendPercent%';
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 28,
      gradient: context.gymHeroGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
                child: Icon(Icons.local_fire_department, color: context.gymFitnessAccent, size: 30),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$streak ${streak == 1 ? 'día' : 'días'} de racha', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.0, color: context.gymText)),
                    SizedBox(height: 5),
                    Text('Último entreno: $latestLogDate', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniHeroStat(
                  label: 'Series semana',
                  value: '$weekSeries',
                  icon: Icons.format_list_numbered,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _MiniHeroStat(
                  label: 'Vs semana ant.',
                  value: trendText,
                  icon: trendPercent >= 0 ? Icons.trending_up : Icons.trending_down,
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }
}

class _MiniHeroStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniHeroStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.gymBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.gymFitnessAccent, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.gymText)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekSummaryCard extends StatelessWidget {
  final int weekSeries;
  final int previousSeries;
  final int weekExercises;
  final int previousExercises;
  final String bestWeight;
  final int pendingGoals;
  final int completedGoals;

  const _WeekSummaryCard({
    required this.weekSeries,
    required this.previousSeries,
    required this.weekExercises,
    required this.previousExercises,
    required this.bestWeight,
    required this.pendingGoals,
    required this.completedGoals,
  });

  String deltaText(int current, int previous) {
    final delta = current - previous;
    if (delta > 0) return '+$delta';
    return delta.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardHeader(icon: Icons.insights, title: 'Tu semana'),
          SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final width = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(width: width, child: _KpiCard(icon: Icons.format_list_numbered, value: '$weekSeries', label: 'Series', subtitle: '${deltaText(weekSeries, previousSeries)} vs anterior')),
                  SizedBox(width: width, child: _KpiCard(icon: Icons.directions_run, value: '$weekExercises', label: 'Ejercicios', subtitle: '${deltaText(weekExercises, previousExercises)} vs anterior')),
                  SizedBox(width: width, child: _KpiCard(icon: Icons.workspace_premium, value: bestWeight, label: 'Mejor marca', subtitle: 'Registro destacado')),
                  SizedBox(width: width, child: _KpiCard(icon: Icons.flag, value: '$pendingGoals', label: 'Objetivos', subtitle: '$completedGoals completados')),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String subtitle;

  const _KpiCard({required this.icon, required this.value, required this.label, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.gymBorder)),
      child: Row(
        children: [
          Icon(icon, color: context.gymFitnessAccent, size: 21),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: context.gymText)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11.5, fontWeight: FontWeight.w800)),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText.withValues(alpha: 0.70), fontSize: 10.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HighlightPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.gymBorder)),
      child: Row(
        children: [
          Icon(icon, color: context.gymFitnessAccent, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _PersonalRankingPreview extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> logsRef;
  final String currentUserId;
  final String currentUserEmail;
  final String currentUserName;
  final String gymId;

  const _PersonalRankingPreview({
    required this.logsRef,
    required this.currentUserId,
    required this.currentUserEmail,
    required this.currentUserName,
    required this.gymId,
  });

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
      stream: logsRef.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(gymStartOfCurrentWeek())).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();
        final docs = snapshot.data?.docs ?? [];
        final map = <String, _RankingLite>{};
        for (final doc in docs) {
          final data = doc.data();
          if (!AppFormatters.isThisWeek(data['createdAt'])) continue;
          final uid = data['userId']?.toString() ?? '';
          final email = (data['userEmail'] ?? '').toString().toLowerCase();
          final key = uid.isNotEmpty ? uid : email;
          if (key.isEmpty) continue;
          final entry = map.putIfAbsent(
            key,
            () => _RankingLite(
              userId: uid,
              userEmail: email,
              userName: data['userName']?.toString() ?? 'Usuario',
            ),
          );
          entry.series += 1;
        }
        final entries = map.values.toList()..sort((a, b) => b.series.compareTo(a.series));
        final currentEmail = currentUserEmail.toLowerCase();
        final index = entries.indexWhere((entry) =>
            (currentUserId.isNotEmpty && entry.userId == currentUserId) ||
            (currentEmail.isNotEmpty && entry.userEmail == currentEmail));
        final positionText = index >= 0 ? '#${index + 1}' : '-';
        final seriesText = index >= 0 ? '${entries[index].series} series' : 'Sin datos esta semana';

        return AppCard(
          padding: const EdgeInsets.all(14),
          radius: 24,
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: Colors.amberAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.leaderboard, color: Colors.amberAccent),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ranking semanal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text(seriesText, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Text(positionText, style: TextStyle(color: context.gymFitnessAccent, fontSize: 24, fontWeight: FontWeight.w900)),
              SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RankingsPage(gymId: gymId, currentUserId: currentUserId, currentUserName: currentUserName, currentUserEmail: currentUserEmail),
                  ),
                ),
                child: Text('Ver'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PhysicalPreview extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;
  final CollectionReference<Map<String, dynamic>> measurementsRef;
  final CollectionReference<Map<String, dynamic>> progressPhotosRef;
  final int totalWorkouts;
  final int totalPoints;
  final String Function(dynamic value) formatDate;
  final double Function(dynamic value) doubleValue;
  final String Function(double value) formatCompactNumber;
  final int Function(dynamic value) timestampSortValue;

  const _PhysicalPreview({
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.measurementsRef,
    required this.progressPhotosRef,
    required this.totalWorkouts,
    required this.totalPoints,
    required this.formatDate,
    required this.doubleValue,
    required this.formatCompactNumber,
    required this.timestampSortValue,
  });

  Query<Map<String, dynamic>> photosQuery() {
    if (userId.trim().isNotEmpty) return progressPhotosRef.where('userId', isEqualTo: userId.trim());
    final normalizedEmail = userEmail.trim().toLowerCase();
    if (normalizedEmail.isNotEmpty) return progressPhotosRef.where('userEmail', isEqualTo: normalizedEmail);
    return progressPhotosRef.limit(1);
  }

  String deltaText(double value, String unit) {
    if (value == 0) return 'Sin cambio';
    final prefix = value > 0 ? '+' : '';
    return '$prefix${formatCompactNumber(value)} $unit';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: measurementsRef.where('userId', isEqualTo: userId).snapshots(),
      builder: (context, measurementsSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: photosQuery().snapshots(),
          builder: (context, photosSnapshot) {
            final measurements = [...(measurementsSnapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])];
            measurements.sort((a, b) => timestampSortValue(a.data()['createdAt']).compareTo(timestampSortValue(b.data()['createdAt'])));
            final firstMeasurement = measurements.isEmpty ? null : measurements.first.data();
            final latestMeasurement = measurements.isEmpty ? null : measurements.last.data();
            final firstWeight = firstMeasurement == null ? 0.0 : doubleValue(firstMeasurement['bodyWeight']);
            final latestWeight = latestMeasurement == null ? 0.0 : doubleValue(latestMeasurement['bodyWeight']);
            final firstWaist = firstMeasurement == null ? 0.0 : doubleValue(firstMeasurement['waist']);
            final latestWaist = latestMeasurement == null ? 0.0 : doubleValue(latestMeasurement['waist']);
            final weightDelta = firstWeight > 0 && latestWeight > 0 ? latestWeight - firstWeight : 0.0;
            final waistDelta = firstWaist > 0 && latestWaist > 0 ? latestWaist - firstWaist : 0.0;

            final photos = [...(photosSnapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])];
            photos.sort((a, b) => timestampSortValue(a.data()['createdAt']).compareTo(timestampSortValue(b.data()['createdAt'])));
            final beforePhoto = photos.isEmpty ? null : photos.first.data();
            final afterPhoto = photos.length < 2 ? null : photos.last.data();
            final hasBeforeAfter = beforePhoto != null && afterPhoto != null;
            final firstDate = photos.isNotEmpty ? formatDate(photos.first.data()['createdAt']) : 'Sin foto inicial';
            final lastDate = photos.length > 1 ? formatDate(photos.last.data()['createdAt']) : 'Sin foto actual';

            return AppCard(
              padding: const EdgeInsets.all(14),
              radius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _DashboardHeader(icon: Icons.compare_rounded, title: 'Mi transformación')),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProgressPhotosPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail),
                          ),
                        ),
                        icon: const Icon(Icons.photo_library_rounded, size: 18),
                        label: const Text('Fotos'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!hasBeforeAfter)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.gymBorder)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Icons.photo_camera_rounded, color: context.gymPrimary, size: 22),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('Crea tu antes y después', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                        ]),
                        const SizedBox(height: 6),
                        Text('Sube al menos dos fotos de progreso para activar la comparación visual.', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: _TransformationPhotoTile(label: 'ANTES', date: firstDate, imageUrl: beforePhoto['imageUrl']?.toString() ?? '')),
                        const SizedBox(width: 8),
                        Expanded(child: _TransformationPhotoTile(label: 'AHORA', date: lastDate, imageUrl: afterPhoto['imageUrl']?.toString() ?? '')),
                      ],
                    ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 8.0;
                      final width = (constraints.maxWidth - spacing) / 2;
                      return Wrap(spacing: spacing, runSpacing: spacing, children: [
                        SizedBox(width: width, child: _TransformationStat(icon: Icons.monitor_weight_rounded, value: deltaText(weightDelta, 'kg'), label: 'Peso vs inicio')),
                        SizedBox(width: width, child: _TransformationStat(icon: Icons.straighten_rounded, value: deltaText(waistDelta, 'cm'), label: 'Cintura vs inicio')),
                        SizedBox(width: width, child: _TransformationStat(icon: Icons.fitness_center_rounded, value: totalWorkouts.toString(), label: 'Entrenos totales')),
                        SizedBox(width: width, child: _TransformationStat(icon: Icons.emoji_events_rounded, value: '$totalPoints pts', label: 'Puntos ganados')),
                      ]);
                    },
                  ),
                  if (latestMeasurement != null) ...[
                    const SizedBox(height: 8),
                    Text('Última medida: ${formatDate(latestMeasurement['createdAt'])}', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TransformationPhotoTile extends StatelessWidget {
  final String label;
  final String date;
  final String imageUrl;
  const _TransformationPhotoTile({required this.label, required this.date, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.gymBorder)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isEmpty)
            ColoredBox(color: context.gymSubtleSurface, child: Icon(Icons.photo_rounded, color: context.gymMutedText.withValues(alpha: 0.55), size: 32))
          else
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(color: context.gymSubtleSurface, child: Icon(Icons.broken_image_rounded, color: context.gymMutedText.withValues(alpha: 0.55), size: 32)),
            ),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.56), borderRadius: BorderRadius.circular(999)),
              child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.50), borderRadius: BorderRadius.circular(12)),
              child: Text(date, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransformationStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _TransformationStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.gymBorder)),
      child: Row(children: [
        Icon(icon, color: context.gymFitnessAccent, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _DashboardHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: context.gymFitnessAccent, size: 20),
        ),
        SizedBox(width: 10),
        Expanded(child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.gymText))),
      ],
    );
  }
}

class _MeasureCard extends StatelessWidget {
  final String value;
  final String unit;
  final String label;

  const _MeasureCard({required this.value, required this.unit, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.gymBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.0, color: context.gymText)),
          SizedBox(height: 2),
          Text(unit, style: TextStyle(color: context.gymFitnessAccent, fontWeight: FontWeight.w900, fontSize: 12)),
          SizedBox(height: 7),
          Text(label, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RankingLite {
  final String userId;
  final String userEmail;
  final String userName;
  int series = 0;

  _RankingLite({required this.userId, required this.userEmail, required this.userName});
}

class TopRankingPreview extends StatelessWidget {
  final String gymId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserEmail;

  const TopRankingPreview({super.key, required this.gymId, required this.currentUserId, required this.currentUserName, required this.currentUserEmail});

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('workout_logs');

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
      stream: logsRef.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(gymStartOfCurrentWeek())).snapshots(),
      builder: (context, snapshot) {
        final logs = snapshot.data?.docs ?? [];
        final Map<String, _TopEntry> map = {};
        for (final doc in logs) {
          final data = doc.data();
          if (!AppFormatters.isThisWeek(data['createdAt'])) continue;
          final userId = data['userId']?.toString() ?? '';
          final userEmail = (data['userEmail'] ?? '').toString().toLowerCase();
          final key = userId.isNotEmpty ? userId : userEmail;
          if (key.isEmpty) continue;
          final name = data['userName']?.toString().trim();
          final entry = map.putIfAbsent(key, () => _TopEntry(userId: userId, name: name == null || name.isEmpty ? 'Usuario' : name));
          entry.series += 1;
        }
        final entries = map.values.toList()..sort((a, b) => b.series.compareTo(a.series));
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.leaderboard, color: context.gymFitnessAccent),
                  SizedBox(width: 8),
                  Expanded(child: Text('Top DalaiGym esta semana', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.gymText))),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RankingsPage(gymId: gymId, currentUserId: currentUserId, currentUserName: currentUserName, currentUserEmail: currentUserEmail))),
                    child: Text('Ver'),
                  ),
                ],
              ),
              SizedBox(height: 10),
              if (entries.isEmpty)
                Text('Aún no hay series registradas esta semana.', style: TextStyle(color: context.gymMutedText))
              else
                ...entries.take(3).toList().asMap().entries.map((item) {
                  final index = item.key;
                  final entry = item.value;
                  final medal = index == 0 ? '🥇' : index == 1 ? '🥈' : '🥉';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 30, child: Text(medal, style: TextStyle(fontSize: 18))),
                        Expanded(child: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800))),
                        Text('${entry.series} series', style: TextStyle(color: context.gymFitnessAccent, fontWeight: FontWeight.w900)),
                      ],
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

class _TopEntry {
  final String userId;
  final String name;
  int series = 0;

  _TopEntry({required this.userId, required this.name});
}




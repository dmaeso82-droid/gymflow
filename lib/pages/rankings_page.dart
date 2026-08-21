import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/points_service.dart';
import '../services/navigation_service.dart';
import '../services/subscription_service.dart';
import '../widgets/app_card.dart';
import '../widgets/profile_avatar.dart';
import 'user_profile_page.dart';
import 'subscription_upgrade_page.dart';

class RankingsPage extends StatefulWidget {
  final String gymId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserEmail;
  const RankingsPage({super.key, required this.gymId, required this.currentUserId, required this.currentUserName, required this.currentUserEmail});

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> {
  String selectedRanking = 'monthly_points';
  String selectedPeriod = 'week';
  SubscriptionService get subscriptionService => SubscriptionService(gymId: widget.gymId);
  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('workout_logs');
  CollectionReference<Map<String, dynamic>> get pointsRef => FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('ranking_points');
  CollectionReference<Map<String, dynamic>> get rankingStatsRef => FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('ranking_stats');
  CollectionReference<Map<String, dynamic>> get leaderboardRef => FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('leaderboard');

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

  bool isThisWeek(dynamic value) {
    if (value is! Timestamp) return false;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    final date = value.toDate();
    return !date.isBefore(startOfWeek) && date.isBefore(endOfWeek);
  }

  DateTime? dayFromTimestamp(dynamic value) {
    if (value is! Timestamp) return null;
    final date = value.toDate();
    return DateTime(date.year, date.month, date.day);
  }

  String formatNumber(num value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  bool get isLeaderboardRanking => selectedRanking == 'monthly_points' || selectedRanking == 'yearly_points' || selectedRanking == 'alltime_points';

  String leaderboardField() {
    switch (selectedRanking) {
      case 'monthly_points':
        return 'monthlyPoints';
      case 'yearly_points':
        return 'yearlyPoints';
      case 'alltime_points':
      default:
        return 'allTimePoints';
    }
  }

  String leaderboardLabel() {
    switch (selectedRanking) {
      case 'monthly_points':
        return 'Ranking mensual';
      case 'yearly_points':
        return 'Ranking anual';
      case 'alltime_points':
      default:
        return 'Ranking histórico';
    }
  }

  List<RankingEntry> buildLeaderboardEntries(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final field = leaderboardField();
    final entries = docs.map((doc) {
      final data = doc.data();
      final points = intValue(data[field]);
      return RankingEntry(userId: data['userId']?.toString() ?? doc.id, userName: data['userName']?.toString() ?? 'Usuario', userEmail: data['userEmail']?.toString() ?? '')
        ..points = points
        ..prestige = prestigeForPoints(points)
        ..prestigeTitle = prestigeTitleForStats(points: points);
    }).where((entry) => entry.points > 0).toList();
    entries.sort((a, b) => b.points.compareTo(a.points));
    return entries;
  }

  List<RankingEntry> buildEntries(List<QueryDocumentSnapshot<Map<String, dynamic>>> logs) {
    final Map<String, RankingEntry> map = {};
    for (final doc in logs) {
      final data = doc.data();
      if (selectedPeriod == 'week' && !isThisWeek(data['createdAt'])) continue;
      final userId = data['userId']?.toString() ?? '';
      final userEmail = (data['userEmail'] ?? '').toString().toLowerCase();
      final key = userId.isNotEmpty ? userId : userEmail;
      if (key.isEmpty) continue;
      final userName = data['userName']?.toString().trim();
      final exercise = data['exercise']?.toString().trim() ?? '';
      final weight = doubleValue(data['weight']);
      final reps = intValue(data['reps']);
      final day = dayFromTimestamp(data['createdAt']);
      final entry = map.putIfAbsent(key, () => RankingEntry(userId: userId, userName: userName == null || userName.isEmpty ? 'Usuario' : userName, userEmail: userEmail));
      entry.series += 1;
      entry.volume += weight * reps;
      if (exercise.isNotEmpty) entry.exercises.add(exercise);
      if (day != null) entry.trainingDays.add(day);
      if (weight > entry.bestWeight || (weight == entry.bestWeight && reps > entry.bestReps)) {
        entry.bestWeight = weight;
        entry.bestReps = reps;
        entry.bestExercise = exercise;
      }
    }
    final entries = map.values.toList();
    for (final entry in entries) {
      entry.streak = calculateStreak(entry.trainingDays);
    }
    entries.sort((a, b) {
      switch (selectedRanking) {
        case 'streak':
          return b.streak.compareTo(a.streak);
        case 'series':
          return b.series.compareTo(a.series);
        case 'volume':
          return b.volume.compareTo(a.volume);
        case 'workouts':
        default:
          return b.trainingDays.length.compareTo(a.trainingDays.length);
      }
    });
    return entries;
  }

  List<RankingEntry> buildStatEntries(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final entries = docs.map((doc) {
      final data = doc.data();
      final entry = RankingEntry(userId: data['userId']?.toString() ?? doc.id, userName: data['userName']?.toString() ?? 'Usuario', userEmail: data['userEmail']?.toString() ?? '');
      if (selectedPeriod == 'week') {
        entry.series = intValue(data['weeklySeries']);
        entry.volume = doubleValue(data['weeklyVolume']);
        entry.workouts = intValue(data['weeklyWorkouts']);
      } else {
        entry.series = intValue(data['totalSeries']);
        entry.volume = doubleValue(data['totalVolume']);
        entry.workouts = intValue(data['totalWorkouts']);
      }
      entry.points = intValue(data['points']);
      entry.prestige = prestigeForPoints(entry.points);
      entry.prestigeTitle = prestigeTitleForStats(points: entry.points);
      final exerciseNames = data['exerciseNames'];
      if (exerciseNames is Map) entry.exercises.addAll(exerciseNames.keys.map((item) => item.toString()));
      return entry;
    }).where((entry) {
      if (selectedRanking == 'series') return entry.series > 0;
      if (selectedRanking == 'volume') return entry.volume > 0;
      if (selectedRanking == 'workouts') return entry.workouts > 0;
      return true;
    }).toList();
    entries.sort((a, b) {
      switch (selectedRanking) {
        case 'series':
          return b.series.compareTo(a.series);
        case 'volume':
          return b.volume.compareTo(a.volume);
        case 'workouts':
        default:
          return b.workouts.compareTo(a.workouts);
      }
    });
    return entries;
  }

  int calculateStreak(Set<DateTime> days) {
    if (days.isEmpty) return 0;
    var currentDay = DateTime.now();
    currentDay = DateTime(currentDay.year, currentDay.month, currentDay.day);
    var streak = 0;
    if (!days.contains(currentDay)) {
      final yesterday = currentDay.subtract(const Duration(days: 1));
      if (days.contains(yesterday)) {
        currentDay = yesterday;
      } else {
        return 0;
      }
    }
    while (days.contains(currentDay)) {
      streak += 1;
      currentDay = currentDay.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String rankingValue(RankingEntry entry) {
    switch (selectedRanking) {
      case 'monthly_points':
      case 'yearly_points':
      case 'alltime_points':
        return '${entry.points} pts';
      case 'streak':
        return '${entry.streak} días';
      case 'series':
        return '${entry.series} series';
      case 'volume':
        return '${formatNumber(entry.volume)} kg';
      case 'workouts':
      default:
        return '${entry.workouts > 0 ? entry.workouts : entry.trainingDays.length} entrenos';
    }
  }

  String rankingDescription(RankingEntry entry) {
    if (isLeaderboardRanking) return '${leaderboardLabel()} · puntos acumulados en ${context.gymBrandName}';
    final best = entry.bestExercise.isEmpty ? 'Sin marca destacada' : '${entry.bestExercise} · ${formatNumber(entry.bestWeight)} kg x ${entry.bestReps}';
    return entry.bestExercise.isEmpty && entry.exercises.isNotEmpty ? '${entry.exercises.length} ejercicios registrados' : '${entry.exercises.length} ejercicios · $best';
  }

  Query<Map<String, dynamic>> rankingLogsQuery() {
    if (selectedPeriod == 'week') {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - DateTime.monday));
      return logsRef.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek));
    }
    return logsRef;
  }

  Widget filterChip(String id, String text, IconData icon) {
    final selected = selectedRanking == id;
    return ChoiceChip(selected: selected, avatar: Icon(icon, size: 16, color: selected ? context.gymText : context.gymPrimary), label: Text(text), onSelected: (_) => setState(() => selectedRanking = id), selectedColor: context.gymPrimary.withValues(alpha: context.gymIsDark ? 0.24 : 0.16), labelStyle: TextStyle(color: selected ? context.gymPrimaryStrong : context.gymText, fontWeight: FontWeight.w800), backgroundColor: context.gymSubtleSurface, side: BorderSide(color: context.gymBorder));
  }

  Widget periodChip(String id, String text) {
    final selected = selectedPeriod == id;
    return ChoiceChip(selected: selected, label: Text(text), onSelected: (_) => setState(() => selectedPeriod = id), selectedColor: context.gymPrimary.withValues(alpha: context.gymIsDark ? 0.24 : 0.16), labelStyle: TextStyle(color: selected ? context.gymPrimaryStrong : context.gymText, fontWeight: FontWeight.w800), backgroundColor: context.gymSubtleSurface, side: BorderSide(color: context.gymBorder));
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    return StreamBuilder<GymSubscriptionPlan>(
      stream: subscriptionService.watchPlan(),
      builder: (context, planSnapshot) {
        final plan = planSnapshot.data ?? GymSubscriptionPlan.fallback(widget.gymId);
        if (!plan.isActive || !plan.rankingsEnabled) {
          return SubscriptionUpgradePage(gymId: widget.gymId, featureName: 'Rankings', reason: !plan.isActive ? 'La suscripción del gimnasio no está activa.' : 'Los rankings no están incluidos en el plan ${plan.plan}.');
        }
        return Scaffold(
          appBar: AppBar(title: Text('Rankings ${context.gymBrandName}')),
          body: SafeArea(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: selectedRanking == 'streak' ? rankingLogsQuery().snapshots() : isLeaderboardRanking ? leaderboardRef.snapshots() : rankingStatsRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: context.gymPrimary));
                final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.data?.docs ?? []);
                final entries = selectedRanking == 'streak' ? buildEntries(docs) : isLeaderboardRanking ? buildLeaderboardEntries(docs) : buildStatEntries(docs);
                return ListView(padding: EdgeInsets.all(isCompact ? 12 : 16), children: [
                  AppCard(child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.amberAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)), child: Icon(Icons.leaderboard, color: Colors.amberAccent)), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Rankings ${context.gymBrandName}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('Compite por puntos mensuales, anuales e históricos, y compara entrenos, rachas, series y volumen.', style: TextStyle(color: context.gymMutedText))]))])),
                  SizedBox(height: 12),
                  AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Tipo de ranking', style: TextStyle(fontWeight: FontWeight.w900)), SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: [filterChip('monthly_points', 'Mensual', Icons.emoji_events), filterChip('yearly_points', 'Anual', Icons.workspace_premium), filterChip('alltime_points', 'Histórico', Icons.military_tech), filterChip('workouts', 'Entrenos', Icons.fitness_center), filterChip('streak', 'Rachas', Icons.local_fire_department), filterChip('series', 'Series', Icons.format_list_numbered), filterChip('volume', 'Volumen', Icons.monitor_weight)]), if (!isLeaderboardRanking) ...[SizedBox(height: 14), Text('Periodo', style: TextStyle(fontWeight: FontWeight.w900)), SizedBox(height: 10), Wrap(spacing: 8, children: [periodChip('week', 'Esta semana'), periodChip('all', 'Total')])]])),
                  SizedBox(height: 12),
                  if (entries.isEmpty)
                    AppCard(child: Text('Todavía no hay datos suficientes para mostrar rankings.', style: TextStyle(color: context.gymMutedText)))
                  else ...[
                    if (isLeaderboardRanking && entries.isNotEmpty) ...[PodiumCard(entries: entries.take(3).toList(), valueBuilder: rankingValue, currentUserId: widget.currentUserId, gymId: widget.gymId, title: leaderboardLabel()), SizedBox(height: 12)],
                    ...entries.take(30).toList().asMap().entries.map((item) => RankingTile(position: item.key + 1, entry: item.value, value: rankingValue(item.value), description: rankingDescription(item.value), currentUserId: widget.currentUserId, gymId: widget.gymId)),
                  ],
                ]);
              },
            ),
          ),
        );
      },
    );
  }
}

class RankingEntry {
  final String userId;
  final String userName;
  final String userEmail;
  int series = 0;
  int workouts = 0;
  int points = 0;
  PrestigeLevel prestige = prestigeForPoints(0);
  PrestigeTitle prestigeTitle = prestigeTitleForStats(points: 0);
  double volume = 0;
  int streak = 0;
  double bestWeight = 0;
  int bestReps = 0;
  String bestExercise = '';
  final Set<DateTime> trainingDays = {};
  final Set<String> exercises = {};
  RankingEntry({required this.userId, required this.userName, required this.userEmail});
}

class PodiumCard extends StatelessWidget {
  final List<RankingEntry> entries;
  final String Function(RankingEntry entry) valueBuilder;
  final String currentUserId;
  final String gymId;
  final String title;
  const PodiumCard({super.key, required this.entries, required this.valueBuilder, required this.currentUserId, required this.gymId, required this.title});
  List<RankingEntry?> orderedPodium() {
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;
    return [second, first, third];
  }

  @override
  Widget build(BuildContext context) {
    final podium = orderedPodium();
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.emoji_events, color: Colors.amberAccent), const SizedBox(width: 8), Expanded(child: Text('Podio $title', style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900, fontSize: 18)))]), const SizedBox(height: 12), Row(crossAxisAlignment: CrossAxisAlignment.end, children: podium.asMap().entries.map((item) {
      final columnIndex = item.key;
      final entry = item.value;
      final position = columnIndex == 1 ? 1 : columnIndex == 0 ? 2 : 3;
      final height = position == 1 ? 118.0 : 102.0;
      return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: entry == null ? Container(height: height, decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.gymBorder))) : InkWell(borderRadius: BorderRadius.circular(18), onTap: () => AppNavigation.push(context, UserProfilePage(gymId: gymId, userId: entry.userId, userName: entry.userName, userEmail: entry.userEmail)), child: Container(height: height, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: position == 1 ? Colors.amberAccent.withValues(alpha: 0.14) : context.gymSubtleSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: position == 1 ? Colors.amberAccent.withValues(alpha: 0.65) : context.gymBorder, width: position == 1 ? 2 : 1)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(position == 1 ? '🥇' : position == 2 ? '🥈' : '🥉', style: TextStyle(fontSize: position == 1 ? 24 : 22)), const SizedBox(height: 6), ProfileAvatar(name: entry.userName, size: position == 1 ? 36 : 32), const SizedBox(height: 6), Text(entry.userName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900, fontSize: 11.5)), const SizedBox(height: 3), Text(valueBuilder(entry), textAlign: TextAlign.center, style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w900, fontSize: position == 1 ? 18 : 16)), const SizedBox(height: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)), child: Text(entry.prestigeTitle.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w900, fontSize: 10)))])))));
    }).toList())]));
  }
}

class RankingTile extends StatelessWidget {
  final int position;
  final RankingEntry entry;
  final String value;
  final String description;
  final String currentUserId;
  final String gymId;
  const RankingTile({super.key, required this.position, required this.entry, required this.value, required this.description, required this.currentUserId, required this.gymId});
  Color medalColor(BuildContext context) {
    if (position == 1) return Colors.amberAccent;
    if (position == 2) return Colors.blueGrey.shade100;
    if (position == 3) return Colors.orangeAccent;
    return context.gymPrimary;
  }

  String medalText() {
    if (position == 1) return '🥇';
    if (position == 2) return '🥈';
    if (position == 3) return '🥉';
    return '#$position';
  }

  @override
  Widget build(BuildContext context) {
    final isMe = currentUserId.isNotEmpty && entry.userId == currentUserId;
    return AppCard(margin: const EdgeInsets.only(bottom: 10), child: Row(children: [SizedBox(width: 42, child: Text(medalText(), textAlign: TextAlign.center, style: TextStyle(fontSize: position <= 3 ? 24 : 16, fontWeight: FontWeight.w900, color: medalColor(context)))), SizedBox(width: 10), GestureDetector(onTap: () => AppNavigation.push(context, UserProfilePage(gymId: gymId, userId: entry.userId, userName: entry.userName, userEmail: entry.userEmail)), child: ProfileAvatar(name: entry.userName, size: 42)), SizedBox(width: 12), Expanded(child: GestureDetector(onTap: () => AppNavigation.push(context, UserProfilePage(gymId: gymId, userId: entry.userId, userName: entry.userName, userEmail: entry.userEmail)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text('${entry.prestige.badge} ${entry.userName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900))), if (isMe) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)), child: Text('Tú', style: TextStyle(fontSize: 11, color: context.gymPrimary, fontWeight: FontWeight.w900)))]), SizedBox(height: 3), Text('${entry.prestige.label} · ${entry.prestigeTitle.label} · $description', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12))]))), SizedBox(width: 10), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: context.gymPrimary.withValues(alpha: 0.16))), child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, color: context.gymPrimary, fontSize: 13)))]));
  }
}

class _SubscriptionLockedPage extends StatelessWidget {
  final String featureName;
  final String reason;
  const _SubscriptionLockedPage({required this.featureName, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(featureName)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 42, color: context.gymPrimary),
                  const SizedBox(height: 12),
                  Text(
                    '$featureName bloqueado',
                    style: TextStyle(color: context.gymText, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

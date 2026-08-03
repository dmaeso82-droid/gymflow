
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/profile_avatar.dart';

class RankingsPage extends StatefulWidget {
  final String gymId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserEmail;

  const RankingsPage({
    super.key,
    required this.gymId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserEmail,
  });

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> {
  String selectedRanking = 'workouts';
  String selectedPeriod = 'week';

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('workout_logs');

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
    return value.toStringAsFixed(1);
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

      final entry = map.putIfAbsent(
        key,
        () => RankingEntry(
          userId: userId,
          userName: userName == null || userName.isEmpty ? 'Usuario' : userName,
          userEmail: userEmail,
        ),
      );

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
      case 'streak':
        return '${entry.streak} días';
      case 'series':
        return '${entry.series} series';
      case 'volume':
        return '${formatNumber(entry.volume)} kg';
      case 'workouts':
      default:
        return '${entry.trainingDays.length} entrenos';
    }
  }

  String rankingDescription(RankingEntry entry) {
    final best = entry.bestExercise.isEmpty
        ? 'Sin marca destacada'
        : '${entry.bestExercise} · ${formatNumber(entry.bestWeight)} kg x ${entry.bestReps}';
    return '${entry.exercises.length} ejercicios · $best';
  }

  Widget filterChip(String id, String text, IconData icon) {
    final selected = selectedRanking == id;
    return ChoiceChip(
      selected: selected,
      avatar: Icon(icon, size: 16, color: selected ? Colors.black : Colors.greenAccent),
      label: Text(text),
      onSelected: (_) => setState(() => selectedRanking = id),
      selectedColor: Colors.greenAccent,
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white,
        fontWeight: FontWeight.w800,
      ),
      backgroundColor: const Color(0xFF020617),
      side: const BorderSide(color: Colors.white10),
    );
  }

  Widget periodChip(String id, String text) {
    final selected = selectedPeriod == id;
    return ChoiceChip(
      selected: selected,
      label: Text(text),
      onSelected: (_) => setState(() => selectedPeriod = id),
      selectedColor: Colors.greenAccent,
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white,
        fontWeight: FontWeight.w800,
      ),
      backgroundColor: const Color(0xFF020617),
      side: const BorderSide(color: Colors.white10),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(title: const Text('Rankings DalaiGym')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: logsRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final logs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.data?.docs ?? []);
            final entries = buildEntries(logs);

            return ListView(
              padding: EdgeInsets.all(isCompact ? 12 : 16),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.leaderboard, color: Colors.amberAccent),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rankings DalaiGym',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Compara entrenamientos, rachas, series y volumen dentro del gimnasio.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tipo de ranking',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          filterChip('workouts', 'Entrenos', Icons.fitness_center),
                          filterChip('streak', 'Rachas', Icons.local_fire_department),
                          filterChip('series', 'Series', Icons.format_list_numbered),
                          filterChip('volume', 'Volumen', Icons.monitor_weight),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Periodo',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          periodChip('week', 'Esta semana'),
                          periodChip('all', 'Total'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (entries.isEmpty)
                  const AppCard(
                    child: Text(
                      'Todavía no hay datos suficientes para mostrar rankings. Se actualizarán cuando los usuarios registren entrenamientos.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                else
                  ...entries.take(30).toList().asMap().entries.map((item) {
                    final index = item.key;
                    final entry = item.value;
                    return RankingTile(
                      position: index + 1,
                      entry: entry,
                      value: rankingValue(entry),
                      description: rankingDescription(entry),
                      currentUserId: widget.currentUserId,
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class RankingEntry {
  final String userId;
  final String userName;
  final String userEmail;
  int series = 0;
  double volume = 0;
  int streak = 0;
  double bestWeight = 0;
  int bestReps = 0;
  String bestExercise = '';
  final Set<DateTime> trainingDays = {};
  final Set<String> exercises = {};

  RankingEntry({
    required this.userId,
    required this.userName,
    required this.userEmail,
  });
}

class RankingTile extends StatelessWidget {
  final int position;
  final RankingEntry entry;
  final String value;
  final String description;
  final String currentUserId;

  const RankingTile({
    super.key,
    required this.position,
    required this.entry,
    required this.value,
    required this.description,
    required this.currentUserId,
  });

  Color medalColor() {
    if (position == 1) return Colors.amberAccent;
    if (position == 2) return Colors.blueGrey.shade100;
    if (position == 3) return Colors.orangeAccent;
    return Colors.greenAccent;
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
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              medalText(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: position <= 3 ? 24 : 16, fontWeight: FontWeight.w900, color: medalColor()),
            ),
          ),
          const SizedBox(width: 10),
          ProfileAvatar(name: entry.userName, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (isMe)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Tú',
                          style: TextStyle(fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.w900),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.greenAccent),
          ),
        ],
      ),
    );
  }
}

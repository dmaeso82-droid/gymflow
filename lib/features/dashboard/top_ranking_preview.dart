part of '../user_dashboard.dart';

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
          padding: const EdgeInsets.all(14),
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.leaderboard_rounded, color: Colors.amberAccent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Top DalaiGym esta semana', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.gymText))),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RankingsPage(gymId: gymId, currentUserId: currentUserId, currentUserName: currentUserName, currentUserEmail: currentUserEmail))),
                    child: const Text('Ver'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (entries.isEmpty)
                Text('Aún no hay series registradas esta semana.', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700))
              else
                Column(
                  children: entries.take(3).toList().asMap().entries.map((item) {
                    final index = item.key;
                    final entry = item.value;
                    final medal = index == 0 ? '🥇' : index == 1 ? '🥈' : '🥉';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.gymSubtleSurface.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: context.gymBorder.withValues(alpha: 0.78)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 34, child: Text(medal, style: const TextStyle(fontSize: 21))),
                          Expanded(child: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: context.gymPrimary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: context.gymPrimary.withValues(alpha: 0.16)),
                            ),
                            child: Text('${entry.series} series', style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
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

class _TopEntry {
  final String userId;
  final String name;
  int series = 0;

  _TopEntry({required this.userId, required this.name});
}

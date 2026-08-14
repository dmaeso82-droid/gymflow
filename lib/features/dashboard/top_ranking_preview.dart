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

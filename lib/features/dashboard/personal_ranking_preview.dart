part of '../user_dashboard.dart';

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
        final seriesText = index >= 0 ? '${entries[index].series} series esta semana' : 'Sin datos esta semana';

        return AppCard(
          padding: const EdgeInsets.all(14),
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.22)),
                    ),
                    child: const Icon(Icons.leaderboard_rounded, color: Colors.amberAccent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ranking semanal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: context.gymText)),
                        const SizedBox(height: 3),
                        Text(seriesText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.gymPrimary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: context.gymPrimary.withValues(alpha: 0.18)),
                    ),
                    child: Text(positionText, style: TextStyle(color: context.gymPrimary, fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RankingsPage(gymId: gymId, currentUserId: currentUserId, currentUserName: currentUserName, currentUserEmail: currentUserEmail),
                    ),
                  ),
                  icon: const Icon(Icons.emoji_events_rounded, size: 18),
                  label: const Text('Ver ranking completo'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

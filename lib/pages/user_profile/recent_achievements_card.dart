part of '../user_profile_page.dart';

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
          padding: const EdgeInsets.all(14),
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(icon: Icons.workspace_premium_rounded, title: 'Últimos logros'),
              const SizedBox(height: 10),
              if (achievements.isEmpty)
                Text('Todavía no hay logros desbloqueados.', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700))
              else
                Column(
                  children: achievements.take(4).map((doc) {
                    final data = doc.data();
                    final title = data['title']?.toString() ?? 'Logro';
                    final description = data['description']?.toString() ?? '';
                    final date = AppFormatters.formatDate(data['unlockedAt'] ?? data['createdAt']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: context.gymSubtleSurface.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.18)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(color: Colors.amberAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(15)),
                            child: const Icon(Icons.emoji_events_rounded, color: Colors.amberAccent),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900)),
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(description, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ProfileChip(icon: Icons.calendar_today_rounded, text: date),
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

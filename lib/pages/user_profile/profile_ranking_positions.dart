part of '../user_profile_page.dart';

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
        final positions = <_RankingPositionData>[
          if (monthly > 0) _RankingPositionData(icon: '📅', label: 'Mensual', position: monthly),
          if (yearly > 0) _RankingPositionData(icon: '🏆', label: 'Anual', position: yearly),
          if (allTime > 0) _RankingPositionData(icon: '⭐', label: 'Histórico', position: allTime),
        ];

        return AppCard(
          padding: const EdgeInsets.all(14),
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(icon: Icons.leaderboard_rounded, title: 'Posición en rankings'),
              const SizedBox(height: 10),
              if (positions.isEmpty)
                Text('Todavía no hay puntos suficientes para calcular posición en ranking.', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700))
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 8.0;
                    final width = (constraints.maxWidth - spacing * (positions.length - 1).clamp(0, 2)) / positions.length.clamp(1, 3);
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: positions.map((item) => SizedBox(width: width, child: _RankingPositionCard(data: item))).toList(),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RankingPositionData {
  final String icon;
  final String label;
  final int position;

  const _RankingPositionData({required this.icon, required this.label, required this.position});
}

class _RankingPositionCard extends StatelessWidget {
  final _RankingPositionData data;

  const _RankingPositionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final medal = data.position == 1 ? '🥇' : data.position == 2 ? '🥈' : data.position == 3 ? '🥉' : '#${data.position}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.gymBorder.withValues(alpha: 0.78)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.icon, style: const TextStyle(fontSize: 19)),
          const SizedBox(height: 8),
          Text(medal, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymPrimary, fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
          const SizedBox(height: 3),
          Text(data.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

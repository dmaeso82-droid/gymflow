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
        if (monthly == 0 && yearly == 0 && allTime == 0) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(icon: Icons.leaderboard, title: 'Posición en rankings'),
                const SizedBox(height: 8),
                Text('Todavía no hay puntos suficientes para calcular posición en ranking.', style: TextStyle(color: context.gymMutedText)),
              ],
            ),
          );
        }
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(icon: Icons.leaderboard, title: 'Posición en rankings'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (monthly > 0) _ProfileChip(text: '#$monthly mensual'),
                  if (yearly > 0) _ProfileChip(text: '#$yearly anual'),
                  if (allTime > 0) _ProfileChip(text: '#$allTime histórico'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

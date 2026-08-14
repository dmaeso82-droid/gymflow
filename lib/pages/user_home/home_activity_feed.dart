part of '../user_home_page.dart';

class _HomeActivityFeed extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userEmail;
  final VoidCallback onOpenCommunity;

  const _HomeActivityFeed({
    required this.gymId,
    required this.userId,
    required this.userEmail,
    required this.onOpenCommunity,
  });

  CollectionReference<Map<String, dynamic>> get activityRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('activity');
  CollectionReference<Map<String, dynamic>> get postsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('community_posts');

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final itemDay = DateTime(date.year, date.month, date.day);
      if (itemDay == today) return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    }
    return '';
  }

  IconData iconForType(String type) {
    if (type.contains('record')) return Icons.workspace_premium;
    if (type.contains('challenge') || type.contains('duel')) return Icons.emoji_events;
    if (type.contains('goal')) return Icons.flag;
    if (type.contains('routine') || type.contains('workout')) return Icons.fitness_center;
    if (type.contains('photo')) return Icons.photo_camera;
    return Icons.bolt;
  }

  String titleFromData(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final user = data['userName']?.toString().trim().isNotEmpty == true
        ? data['userName'].toString()
        : data['user']?.toString().trim().isNotEmpty == true
            ? data['user'].toString()
            : 'DalaiGym';
    final message = data['message']?.toString().trim() ?? '';
    final title = data['title']?.toString().trim() ?? '';
    if (title.isNotEmpty) return title;
    if (message.isNotEmpty) return message;
    if (type.contains('record')) return '$user consiguió un nuevo récord';
    if (type.contains('challenge')) return '$user completó un reto';
    if (type.contains('duel')) return '$user inició un duelo';
    if (type.contains('goal')) return '$user actualizó un objetivo';
    if (type.contains('routine') || type.contains('workout')) return '$user completó un entrenamiento';
    return '$user publicó una actualización';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: activityRef.orderBy('createdAt', descending: true).limit(4).snapshots(),
      builder: (context, activitySnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: postsRef.orderBy('createdAt', descending: true).limit(4).snapshots(),
          builder: (context, postsSnapshot) {
            final items = <_FeedItem>[];
            for (final doc in activitySnapshot.data?.docs ?? []) {
              final data = doc.data();
              items.add(_FeedItem(
                icon: iconForType(data['type']?.toString() ?? ''),
                title: titleFromData(data),
                subtitle: formatDate(data['createdAt']),
                createdAt: data['createdAt'],
              ));
            }
            for (final doc in postsSnapshot.data?.docs ?? []) {
              final data = doc.data();
              items.add(_FeedItem(
                icon: iconForType(data['type']?.toString() ?? ''),
                title: titleFromData(data),
                subtitle: formatDate(data['createdAt']),
                createdAt: data['createdAt'],
              ));
            }
            items.sort((a, b) {
              final aMillis = a.createdAt is Timestamp ? (a.createdAt as Timestamp).millisecondsSinceEpoch : 0;
              final bMillis = b.createdAt is Timestamp ? (b.createdAt as Timestamp).millisecondsSinceEpoch : 0;
              return bMillis.compareTo(aMillis);
            });
            final visible = items.take(4).toList();
            return AppCard(
              padding: const EdgeInsets.all(14),
              radius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _SectionTitle(icon: Icons.dynamic_feed, title: 'Actividad reciente')),
                      TextButton(onPressed: onOpenCommunity, child: Text('Ver')),
                    ],
                  ),
                  SizedBox(height: 10),
                  if (activitySnapshot.hasError || postsSnapshot.hasError)
                    Text('No se ha podido cargar la actividad reciente.', style: TextStyle(color: context.gymMutedText))
                  else if (visible.isEmpty)
                    Text('Cuando haya entrenos, retos, récords o publicaciones, aparecerán aquí.', style: TextStyle(color: context.gymMutedText))
                  else
                    ...visible.map((item) => _FeedTile(item: item)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _FeedItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final dynamic createdAt;

  const _FeedItem({required this.icon, required this.title, required this.subtitle, required this.createdAt});
}

class _FeedTile extends StatelessWidget {
  final _FeedItem item;

  const _FeedTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.gymBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.gymFitnessAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(item.icon, color: context.gymPrimary, size: 19),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
          if (item.subtitle.isNotEmpty) ...[
            SizedBox(width: 8),
            Text(item.subtitle, style: TextStyle(color: context.gymMutedText.withValues(alpha: 0.70), fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

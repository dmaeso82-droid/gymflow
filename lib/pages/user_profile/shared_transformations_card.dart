part of '../user_profile_page.dart';

class _SharedTransformationsCard extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> communityPostsRef;
  final String userId;
  final String userEmail;

  const _SharedTransformationsCard({
    required this.communityPostsRef,
    required this.userId,
    required this.userEmail,
  });

  Query<Map<String, dynamic>> scopedQuery() {
    final base = communityPostsRef.where('type', isEqualTo: 'transformation_post');
    if (userId.trim().isNotEmpty) return base.where('userId', isEqualTo: userId.trim());
    return base.where('userEmail', isEqualTo: userEmail.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: scopedQuery().snapshots(),
      builder: (context, snapshot) {
        final posts = (snapshot.data?.docs ?? []).toList();
        posts.sort((a, b) => AppFormatters.timestampSortValue(b.data()['createdAt']).compareTo(AppFormatters.timestampSortValue(a.data()['createdAt'])));
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(icon: Icons.compare, title: 'Transformaciones compartidas'),
              const SizedBox(height: 10),
              if (posts.isEmpty)
                Text('Todavía no hay transformaciones compartidas.', style: TextStyle(color: context.gymMutedText))
              else
                SizedBox(
                  height: 178,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: posts.take(6).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final data = posts[index].data();
                      final before = data['beforeImageUrl']?.toString() ?? '';
                      final after = data['afterImageUrl']?.toString() ?? '';
                      final date = AppFormatters.formatDate(data['createdAt']);
                      return Container(
                        width: 210,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.gymBorder)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text('ANTES', style: TextStyle(color: context.gymPrimary, fontSize: 11, fontWeight: FontWeight.w900))),
                                Expanded(child: Text('DESPUÉS', textAlign: TextAlign.right, style: TextStyle(color: context.gymFitnessAccent, fontSize: 11, fontWeight: FontWeight.w900))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: _TransformationThumb(imageUrl: before)),
                                  const SizedBox(width: 6),
                                  Expanded(child: _TransformationThumb(imageUrl: after)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(date, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TransformationThumb extends StatelessWidget {
  final String imageUrl;

  const _TransformationThumb({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imageUrl.isEmpty
          ? Container(color: context.gymProgressTrack, alignment: Alignment.center, child: Icon(Icons.photo_outlined, color: context.gymMutedText))
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => Container(color: context.gymProgressTrack, alignment: Alignment.center, child: Icon(Icons.broken_image, color: context.gymMutedText)),
            ),
    );
  }
}

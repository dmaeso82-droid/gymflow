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
          padding: const EdgeInsets.all(14),
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(icon: Icons.compare_rounded, title: 'Transformación física'),
              const SizedBox(height: 10),
              if (posts.isEmpty)
                Text('Todavía no hay transformaciones compartidas.', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700))
              else
                SizedBox(
                  height: 196,
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
                        width: 220,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: context.gymSubtleSurface.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.gymBorder.withValues(alpha: 0.78)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _TransformationLabel(text: 'ANTES', color: context.gymPrimary),
                                const Spacer(),
                                _TransformationLabel(text: 'DESPUÉS', color: context.gymFitnessAccent),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: _TransformationThumb(imageUrl: before)),
                                  const SizedBox(width: 7),
                                  Expanded(child: _TransformationThumb(imageUrl: after)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            _ProfileChip(icon: Icons.calendar_today_rounded, text: date),
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

class _TransformationLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _TransformationLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900)),
    );
  }
}

class _TransformationThumb extends StatelessWidget {
  final String imageUrl;

  const _TransformationThumb({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
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

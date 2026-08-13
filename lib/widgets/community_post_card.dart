import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/profile_avatar.dart';

class CommunityPostCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String postId;
  final bool isCompact;
  final String currentUserId;
  final String userName;
  final String dateText;
  final String postTitle;
  final String routineTitle;
  final String message;
  final String previewText;
  final String likesTooltip;
  final IconData icon;
  final List<String> likes;
  final dynamic totalSets;
  final dynamic totalExercises;
  final dynamic commentsCount;
  final VoidCallback onToggleLike;
  final VoidCallback onShowLikes;
  final VoidCallback onOpenComments;
  final void Function(String userId, String userName, String userEmail) onOpenProfile;

  const CommunityPostCard({
    super.key,
    required this.data,
    required this.postId,
    required this.isCompact,
    required this.currentUserId,
    required this.userName,
    required this.dateText,
    required this.postTitle,
    required this.routineTitle,
    required this.message,
    required this.previewText,
    required this.likesTooltip,
    required this.icon,
    required this.likes,
    required this.totalSets,
    required this.totalExercises,
    required this.commentsCount,
    required this.onToggleLike,
    required this.onShowLikes,
    required this.onOpenComments,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    String textValue(String key) => data[key]?.toString().trim() ?? '';
    final liked = likes.contains(currentUserId);
    final postUserId = textValue('userId');
    final postUserEmail = textValue('userEmail');
    final type = textValue('type');
    final beforeImageUrl = textValue('beforeImageUrl').isNotEmpty
        ? textValue('beforeImageUrl')
        : (textValue('beforeUrl').isNotEmpty ? textValue('beforeUrl') : textValue('beforePhotoUrl'));
    final afterImageUrl = textValue('afterImageUrl').isNotEmpty
        ? textValue('afterImageUrl')
        : (textValue('afterUrl').isNotEmpty ? textValue('afterUrl') : textValue('afterPhotoUrl'));
    final beforeDate = textValue('beforeDate');
    final afterDate = textValue('afterDate');
    final isTransformationPost = type == 'transformation_post';
    final hasTransformationImages = beforeImageUrl.isNotEmpty && afterImageUrl.isNotEmpty;
    final shouldShowTransformationBlock = isTransformationPost || hasTransformationImages;

    return AppCard(
      margin: EdgeInsets.only(bottom: isCompact ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => onOpenProfile(postUserId, userName, postUserEmail),
                child: ProfileAvatar(name: userName, size: isCompact ? 42 : 48),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => onOpenProfile(postUserId, userName, postUserEmail),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(dateText, style: TextStyle(color: context.gymMutedText, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              Icon(icon, color: context.gymPrimary, size: 22),
            ],
          ),
          const SizedBox(height: 12),
          Text(postTitle, style: TextStyle(color: context.gymText, fontSize: isCompact ? 17 : 18, fontWeight: FontWeight.w900)),
          if (routineTitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(routineTitle, style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w700)),
          ],
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: context.gymMutedText)),
          ],
          if (shouldShowTransformationBlock) ...[
            const SizedBox(height: 12),
            TransformationPreview(
              beforeImageUrl: beforeImageUrl,
              afterImageUrl: afterImageUrl,
              beforeDate: beforeDate,
              afterDate: afterDate,
              hasImages: hasTransformationImages,
            ),
          ],
          if (totalSets != null || totalExercises != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (totalSets != null) CommunityChip(text: '$totalSets series'),
                if (totalExercises != null) CommunityChip(text: '$totalExercises ejercicios'),
              ],
            ),
          ],
          if (previewText.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onShowLikes,
              onLongPress: onShowLikes,
              child: Text(previewText, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Tooltip(
                message: likesTooltip,
                waitDuration: const Duration(milliseconds: 350),
                child: GestureDetector(
                  onLongPress: onShowLikes,
                  child: TextButton.icon(
                    onPressed: onToggleLike,
                    icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.redAccent : context.gymMutedText, size: 20),
                    label: Text('${likes.length}'),
                  ),
                ),
              ),
              TextButton.icon(onPressed: onOpenComments, icon: const Icon(Icons.chat_bubble_outline, size: 18), label: Text('$commentsCount')),
            ],
          ),
        ],
      ),
    );
  }
}

class TransformationPreview extends StatelessWidget {
  final String beforeImageUrl;
  final String afterImageUrl;
  final String beforeDate;
  final String afterDate;
  final bool hasImages;

  const TransformationPreview({super.key, required this.beforeImageUrl, required this.afterImageUrl, required this.beforeDate, required this.afterDate, required this.hasImages});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.gymBorder)),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.compare, color: context.gymPrimary, size: 18), const SizedBox(width: 6), Expanded(child: Text('Comparación física', style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900)))]),
          if (!hasImages) ...[
            const SizedBox(height: 8),
            Text('Fotos no disponibles en esta publicación. Vuelve a compartir la transformación para regenerarla.', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: TransformationImageTile(label: 'ANTES', imageUrl: beforeImageUrl, date: beforeDate, accentColor: context.gymPrimary)),
              const SizedBox(width: 8),
              Expanded(child: TransformationImageTile(label: 'DESPUÉS', imageUrl: afterImageUrl, date: afterDate, accentColor: context.gymFitnessAccent)),
            ],
          ),
        ],
      ),
    );
  }
}

class TransformationImageTile extends StatelessWidget {
  final String label;
  final String imageUrl;
  final String date;
  final Color accentColor;

  const TransformationImageTile({super.key, required this.label, required this.imageUrl, required this.date, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text(label, style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w900)),
          if (date.isNotEmpty) ...[const SizedBox(width: 6), Expanded(child: Text(date, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: TextStyle(color: context.gymMutedText, fontSize: 11, fontWeight: FontWeight.w700)))],
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: imageUrl.isEmpty
                ? Container(color: context.gymProgressTrack, alignment: Alignment.center, child: Icon(Icons.photo_outlined, color: context.gymMutedText))
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(color: context.gymProgressTrack, alignment: Alignment.center, child: const CircularProgressIndicator(strokeWidth: 2));
                    },
                    errorBuilder: (context, error, stackTrace) => Container(color: context.gymProgressTrack, alignment: Alignment.center, child: Icon(Icons.broken_image, color: context.gymMutedText)),
                  ),
          ),
        ),
      ],
    );
  }
}

class CommunityFilterChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const CommunityFilterChip({super.key, required this.text, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text(text),
        onSelected: (_) => onTap(),
        selectedColor: context.gymPrimary.withValues(alpha: context.gymIsDark ? 0.24 : 0.16),
        backgroundColor: context.gymSubtleSurface,
        side: BorderSide(color: selected ? context.gymStrongBorder : context.gymBorder),
        checkmarkColor: context.gymPrimary,
        labelStyle: TextStyle(color: selected ? context.gymPrimaryStrong : context.gymText, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class CommunityChip extends StatelessWidget {
  final String text;
  const CommunityChip({super.key, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: context.gymIsDark ? 0.14 : 0.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: context.gymFitnessAccent.withValues(alpha: 0.22))),
      child: Text(text, style: TextStyle(color: context.gymFitnessAccent, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

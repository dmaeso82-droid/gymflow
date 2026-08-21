import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
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
  final bool canDelete;
  final VoidCallback onToggleLike;
  final VoidCallback onShowLikes;
  final VoidCallback onOpenComments;
  final VoidCallback? onDeletePost;
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
    this.canDelete = false,
    required this.onToggleLike,
    required this.onShowLikes,
    required this.onOpenComments,
    this.onDeletePost,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    String textValue(String key) => data[key]?.toString().trim() ?? '';
    final liked = likes.contains(currentUserId);
    final postUserId = textValue('userId');
    final postUserEmail = textValue('userEmail');
    final type = textValue('type');
    final beforeImageUrl = textValue('beforeImageUrl').isNotEmpty ? textValue('beforeImageUrl') : (textValue('beforeUrl').isNotEmpty ? textValue('beforeUrl') : textValue('beforePhotoUrl'));
    final afterImageUrl = textValue('afterImageUrl').isNotEmpty ? textValue('afterImageUrl') : (textValue('afterUrl').isNotEmpty ? textValue('afterUrl') : textValue('afterPhotoUrl'));
    final beforeDate = textValue('beforeDate');
    final afterDate = textValue('afterDate');
    final isTransformationPost = type == 'transformation_post';
    final hasTransformationImages = beforeImageUrl.isNotEmpty && afterImageUrl.isNotEmpty;
    final shouldShowTransformationBlock = isTransformationPost || hasTransformationImages;

    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 10 : 12),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.46 : 0.68),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: context.gymIsDark ? 0.12 : 0.045), blurRadius: 18, spreadRadius: -12, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          GestureDetector(onTap: () => onOpenProfile(postUserId, userName, postUserEmail), child: ProfileAvatar(name: userName, size: isCompact ? 40 : 44)),
          const SizedBox(width: 11),
          Expanded(
            child: GestureDetector(
              onTap: () => onOpenProfile(postUserId, userName, postUserEmail),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(dateText, style: TextStyle(color: context.gymMutedText, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          Container(width: 36, height: 36, decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.10), shape: BoxShape.circle), child: Icon(icon, color: context.gymPrimary, size: 19)),
          if (canDelete) ...[
            const SizedBox(width: 2),
            PopupMenuButton<String>(
              tooltip: 'Opciones',
              icon: Icon(Icons.more_vert_rounded, color: context.gymMutedText),
              onSelected: (value) {
                if (value == 'delete') onDeletePost?.call();
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text('Eliminar publicación'),
                  ]),
                ),
              ],
            ),
          ],
        ]),
        const SizedBox(height: 11),
        Text(postTitle, style: TextStyle(color: context.gymText, fontSize: isCompact ? 16.5 : 17.5, fontWeight: FontWeight.w900, height: 1.15)),
        if (routineTitle.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(routineTitle, style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w800)),
        ],
        if (message.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: context.gymMutedText, height: 1.3, fontWeight: FontWeight.w600)),
        ],
        if (shouldShowTransformationBlock) ...[
          const SizedBox(height: 12),
          TransformationPreview(beforeImageUrl: beforeImageUrl, afterImageUrl: afterImageUrl, beforeDate: beforeDate, afterDate: afterDate, hasImages: hasTransformationImages),
        ],
        if (totalSets != null || totalExercises != null) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (totalSets != null) CommunityChip(text: '$totalSets series'),
            if (totalExercises != null) CommunityChip(text: '$totalExercises ejercicios'),
          ]),
        ],
        if (previewText.isNotEmpty) ...[
          const SizedBox(height: 10),
          GestureDetector(onTap: onShowLikes, onLongPress: onShowLikes, child: Text(previewText, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w800))),
        ],
        const SizedBox(height: 8),
        Row(children: [
          _PostActionChip(icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, text: '${likes.length}', color: liked ? Colors.redAccent : context.gymMutedText, onTap: onToggleLike, onLongPress: onShowLikes, tooltip: likesTooltip),
          const SizedBox(width: 8),
          _PostActionChip(icon: Icons.chat_bubble_outline_rounded, text: '$commentsCount', color: context.gymMutedText, onTap: onOpenComments),
        ]),
      ]),
    );
  }
}

class _PostActionChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? tooltip;

  const _PostActionChip({required this.icon, required this.text, required this.color, required this.onTap, this.onLongPress, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 18), const SizedBox(width: 5), Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900))]),
        ),
      ),
    );
    if (tooltip == null || tooltip!.isEmpty) return child;
    return Tooltip(message: tooltip!, waitDuration: const Duration(milliseconds: 350), child: child);
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
      decoration: BoxDecoration(color: context.gymElevatedSurface.withValues(alpha: context.gymIsDark ? 0.44 : 0.58), borderRadius: BorderRadius.circular(22)),
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.10), shape: BoxShape.circle), child: Icon(Icons.compare_rounded, color: context.gymPrimary, size: 17)),
          const SizedBox(width: 8),
          Expanded(child: Text('Comparación física', style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900))),
        ]),
        if (!hasImages) ...[
          const SizedBox(height: 8),
          Text('Fotos no disponibles en esta publicación. Vuelve a compartir la transformación para regenerarla.', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: TransformationImageTile(label: 'ANTES', imageUrl: beforeImageUrl, date: beforeDate, accentColor: context.gymPrimary)),
          const SizedBox(width: 8),
          Expanded(child: TransformationImageTile(label: 'DESPUÉS', imageUrl: afterImageUrl, date: afterDate, accentColor: context.gymFitnessAccent)),
        ]),
      ]),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text(label, style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w900)),
        if (date.isNotEmpty) ...[const SizedBox(width: 6), Expanded(child: Text(date, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: TextStyle(color: context.gymMutedText, fontSize: 11, fontWeight: FontWeight.w700)))],
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: imageUrl.isEmpty
              ? Container(color: context.gymProgressTrack, alignment: Alignment.center, child: Icon(Icons.photo_outlined, color: context.gymMutedText))
              : Image.network(imageUrl, fit: BoxFit.cover, loadingBuilder: (context, child, progress) => progress == null ? child : Container(color: context.gymProgressTrack, alignment: Alignment.center, child: const CircularProgressIndicator(strokeWidth: 2)), errorBuilder: (context, error, stackTrace) => Container(color: context.gymProgressTrack, alignment: Alignment.center, child: Icon(Icons.broken_image, color: context.gymMutedText))),
        ),
      ),
    ]);
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
      child: FilterChip(
        selected: selected,
        label: Text(text),
        onSelected: (_) => onTap(),
        selectedColor: context.gymPrimary.withValues(alpha: context.gymIsDark ? 0.24 : 0.16),
        backgroundColor: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.46 : 0.68),
        side: BorderSide.none,
        showCheckmark: false,
        labelStyle: TextStyle(color: selected ? context.gymPrimaryStrong : context.gymText, fontWeight: FontWeight.w900),
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
      decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: context.gymIsDark ? 0.14 : 0.10), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: context.gymFitnessAccent, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

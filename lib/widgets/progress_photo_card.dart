import 'package:flutter/material.dart';
import '../services/progress_photos_service.dart';
import '../theme/app_theme.dart';

class ProgressPhotoCard extends StatelessWidget {
  final String photoId;
  final Map<String, dynamic> data;
  final ProgressPhotosService service;
  final bool allowDelete;
  final VoidCallback? onDelete;

  const ProgressPhotoCard({
    super.key,
    required this.photoId,
    required this.data,
    required this.service,
    this.allowDelete = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final category = data['category']?.toString() ?? 'free';
    final label = service.categoryLabel(category);
    final date = service.formatDate(data['createdAt']);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: context.gymSurface,
          border: Border.all(color: context.gymBorder),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.gymIsDark ? 0.16 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: Container(
                color: context.gymSubtleSurface,
                child: imageUrl.isEmpty
                    ? Center(
                        child: Icon(Icons.photo, color: context.gymMutedText.withValues(alpha: 0.70), size: 38),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: SingleChildScrollView(
                                child: Text(
                                  error.toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(service.categoryIcon(category), color: context.gymPrimary, size: 17),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(date, style: TextStyle(color: context.gymMutedText, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (allowDelete)
                    IconButton(
                      tooltip: 'Eliminar foto',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

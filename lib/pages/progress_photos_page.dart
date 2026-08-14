import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/achievement_service.dart';
import '../services/progress_photos_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/progress_photo_card.dart';

class ProgressPhotosPage extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;
  final bool allowAdd;

  const ProgressPhotosPage({
    super.key,
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.allowAdd = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Fotos de progreso')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProgressPhotosPanel(
              gymId: gymId,
              userId: userId,
              userName: userName,
              userEmail: userEmail,
              allowAdd: allowAdd,
            ),
          ],
        ),
      ),
    );
  }
}

class ProgressPhotosPanel extends StatefulWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;
  final bool allowAdd;

  const ProgressPhotosPanel({
    super.key,
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.allowAdd = true,
  });

  @override
  State<ProgressPhotosPanel> createState() => _ProgressPhotosPanelState();
}

class _ProgressPhotosPanelState extends State<ProgressPhotosPanel> {
  String selectedCategory = 'all';
  String? selectedBeforePhotoId;
  String? selectedAfterPhotoId;
  bool uploading = false;
  bool sharing = false;

  ProgressPhotosService get service => ProgressPhotosService(gymId: widget.gymId);

  CollectionReference<Map<String, dynamic>> get comparisonSettingsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('progress_photo_settings');

  String get comparisonSettingsDocId {
    if (widget.userId.trim().isNotEmpty) return widget.userId.trim();
    return widget.userEmail.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  DocumentReference<Map<String, dynamic>> get comparisonSettingsDoc =>
      comparisonSettingsRef.doc(comparisonSettingsDocId);

  @override
  void initState() {
    super.initState();
    loadComparisonSettings();
  }

  Future<void> loadComparisonSettings() async {
    if (comparisonSettingsDocId.isEmpty) return;
    try {
      final snapshot = await comparisonSettingsDoc.get();
      final data = snapshot.data();
      if (!mounted || data == null) return;
      setState(() {
        selectedBeforePhotoId = data['beforePhotoId']?.toString();
        selectedAfterPhotoId = data['afterPhotoId']?.toString();
      });
    } catch (_) {
      // Si no hay permisos o todavía no existe el documento, se usa el comparador por defecto.
    }
  }

  Future<void> persistComparisonSelection({String? beforePhotoId, String? afterPhotoId}) async {
    if (comparisonSettingsDocId.isEmpty) return;
    await comparisonSettingsDoc.set({
      'userId': widget.userId,
      'userName': widget.userName,
      'userEmail': widget.userEmail.trim().toLowerCase(),
      if (beforePhotoId != null) 'beforePhotoId': beforePhotoId,
      if (afterPhotoId != null) 'afterPhotoId': afterPhotoId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearDeletedComparisonSelection(String photoId) async {
    final updates = <String, dynamic>{};
    var changed = false;
    if (selectedBeforePhotoId == photoId) {
      selectedBeforePhotoId = null;
      updates['beforePhotoId'] = FieldValue.delete();
      changed = true;
    }
    if (selectedAfterPhotoId == photoId) {
      selectedAfterPhotoId = null;
      updates['afterPhotoId'] = FieldValue.delete();
      changed = true;
    }
    if (changed && comparisonSettingsDocId.isNotEmpty) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await comparisonSettingsDoc.set(updates, SetOptions(merge: true));
      if (mounted) setState(() {});
    }
  }

  Future<void> showUnlockedAchievementDialog(UnlockedAchievementData achievement) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.gymSurface,
          title: Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amberAccent),
              SizedBox(width: 8),
              Expanded(child: Text('Logro desbloqueado')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                achievement.title,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.amberAccent),
              ),
              SizedBox(height: 8),
              Text(achievement.description, style: TextStyle(color: context.gymMutedText)),
              SizedBox(height: 12),
              Text('¿Quieres compartirlo en Comunidad?', style: TextStyle(color: context.gymMutedText)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'close'),
              child: Text('Cerrar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, 'share'),
              icon: Icon(Icons.share),
              label: Text('Compartir'),
            ),
          ],
        );
      },
    );

    if (action == 'share') {
      await service.shareAchievementToCommunity(
        userId: widget.userId,
        userName: widget.userName,
        userEmail: widget.userEmail,
        achievement: achievement,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logro compartido en Comunidad.')));
      }
    }
  }

  Future<void> showUnlockedAchievements(List<UnlockedAchievementData> achievements) async {
    for (final achievement in achievements) {
      if (!mounted) return;
      await showUnlockedAchievementDialog(achievement);
    }
  }

  Future<void> upload(String category) async {
    setState(() => uploading = true);
    try {
      final unlocked = await service.pickAndUploadPhoto(
        userId: widget.userId,
        userName: widget.userName,
        userEmail: widget.userEmail,
        category: category,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto subida.')));
      }
      if (unlocked.isNotEmpty && mounted) {
        await showUnlockedAchievements(unlocked);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo subir la foto: $error')));
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> confirmDelete(String photoId, Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.gymSurface,
          title: Text('Eliminar foto'),
          content: Text('¿Seguro que quieres eliminar esta foto de progreso?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('Cancelar')),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: Icon(Icons.delete_outline),
              label: Text('Eliminar'),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await service.deletePhoto(data, photoId);
      await clearDeletedComparisonSelection(photoId);
    }
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? findPhotoById(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> photos,
    String? photoId,
  ) {
    if (photoId == null || photoId.isEmpty) return null;
    for (final photo in photos) {
      if (photo.id == photoId) return photo;
    }
    return null;
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? defaultBeforePhoto(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orderedPhotos,
  ) {
    if (orderedPhotos.isEmpty) return null;
    return orderedPhotos.first;
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? defaultAfterPhoto(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orderedPhotos,
  ) {
    if (orderedPhotos.length < 2) return null;
    return orderedPhotos.last;
  }

  Future<void> selectComparisonPhoto({
    required bool before,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> photos,
    String? currentSelectedId,
  }) async {
    if (photos.isEmpty) return;

    final selectedId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.gymSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(before ? Icons.looks_one : Icons.looks_two, color: context.gymPrimary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        before ? 'Seleccionar foto ANTES' : 'Seleccionar foto AHORA',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      final photo = photos[index];
                      final data = photo.data();
                      final imageUrl = data['imageUrl']?.toString() ?? '';
                      final category = data['category']?.toString() ?? 'free';
                      final date = service.formatDate(data['createdAt']);
                      final isSelected = (currentSelectedId ?? (before ? selectedBeforePhotoId : selectedAfterPhotoId)) == photo.id;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 54,
                            height: 54,
                            child: imageUrl.isEmpty
                                ? ColoredBox(
                                    color: context.gymSubtleSurface,
                                    child: Icon(Icons.photo, color: context.gymMutedText.withValues(alpha: 0.70)),
                                  )
                                : Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => ColoredBox(
                                      color: context.gymSubtleSurface,
                                      child: Icon(Icons.broken_image, color: context.gymMutedText.withValues(alpha: 0.70)),
                                    ),
                                  ),
                          ),
                        ),
                        title: Text('${service.categoryLabel(category)} · $date'),
                        subtitle: Text(category == 'free' ? 'Foto libre' : 'Categoría: ${service.categoryLabel(category)}'),
                        trailing: isSelected ? Icon(Icons.check_circle, color: context.gymPrimary) : null,
                        onTap: () => Navigator.pop(sheetContext, photo.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedId == null || !mounted) return;
    setState(() {
      if (before) {
        selectedBeforePhotoId = selectedId;
      } else {
        selectedAfterPhotoId = selectedId;
      }
    });
    await persistComparisonSelection(
      beforePhotoId: before ? selectedId : selectedBeforePhotoId,
      afterPhotoId: before ? selectedAfterPhotoId : selectedId,
    );
  }

  Future<void> swapComparisonPhotos() async {
    setState(() {
      final previousBefore = selectedBeforePhotoId;
      selectedBeforePhotoId = selectedAfterPhotoId;
      selectedAfterPhotoId = previousBefore;
    });
    await persistComparisonSelection(
      beforePhotoId: selectedBeforePhotoId,
      afterPhotoId: selectedAfterPhotoId,
    );
  }

  Future<void> shareTransformation({
    required QueryDocumentSnapshot<Map<String, dynamic>> beforePhoto,
    required QueryDocumentSnapshot<Map<String, dynamic>> afterPhoto,
  }) async {
    final messageController = TextEditingController(
      text: 'Comparto mi transformación física 💪',
    );
    try {
      final message = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: context.gymSurface,
            title: Text('Compartir transformación'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Quieres publicarlo en Comunidad?',
                  style: TextStyle(color: context.gymMutedText),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Texto de la publicación',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancelar')),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, messageController.text.trim()),
                icon: Icon(Icons.share),
                label: Text('Compartir'),
              ),
            ],
          );
        },
      );
      if (message == null) return;

      setState(() => sharing = true);
      final unlocked = await service.shareTransformationToCommunity(
        userId: widget.userId,
        userName: widget.userName,
        userEmail: widget.userEmail,
        beforeImageUrl: beforePhoto.data()['imageUrl']?.toString() ?? '',
        afterImageUrl: afterPhoto.data()['imageUrl']?.toString() ?? '',
        beforeDate: service.formatDate(beforePhoto.data()['createdAt']),
        afterDate: service.formatDate(afterPhoto.data()['createdAt']),
        category: selectedCategory,
        message: message,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transformación compartida en Comunidad.')));
      }
      if (unlocked.isNotEmpty && mounted) {
        await showUnlockedAchievements(unlocked);
      }
    } finally {
      messageController.dispose();
      if (mounted) setState(() => sharing = false);
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> orderedByOldest(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> photos,
  ) {
    final ordered = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(photos);
    ordered.sort((a, b) {
      final aDate = a.data()['createdAt'];
      final bDate = b.data()['createdAt'];
      final aMs = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
      final bMs = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;
      return aMs.compareTo(bMs);
    });
    return ordered;
  }


  Query<Map<String, dynamic>> scopedPhotosQuery() {
    if (widget.userId.trim().isNotEmpty) {
      return service.photosRef.where('userId', isEqualTo: widget.userId.trim());
    }
    final normalizedEmail = widget.userEmail.trim().toLowerCase();
    if (normalizedEmail.isNotEmpty) {
      return service.photosRef.where('userEmail', isEqualTo: normalizedEmail);
    }
    return service.photosRef.limit(1);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: scopedPhotosQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppCard(child: Center(child: CircularProgressIndicator()));
        }

        final allPhotos = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.data?.docs ?? [])..sort((a, b) {
          final aValue = a.data()['createdAt'];
          final bValue = b.data()['createdAt'];
          final aMs = aValue is Timestamp ? aValue.millisecondsSinceEpoch : 0;
          final bMs = bValue is Timestamp ? bValue.millisecondsSinceEpoch : 0;
          return bMs.compareTo(aMs);
        });
        final filteredPhotos = selectedCategory == 'all'
            ? allPhotos
            : allPhotos.where((doc) => (doc.data()['category'] ?? 'free').toString() == selectedCategory).toList();
        final orderedPhotos = orderedByOldest(filteredPhotos);

        var beforePhoto = findPhotoById(orderedPhotos, selectedBeforePhotoId) ?? defaultBeforePhoto(orderedPhotos);
        var afterPhoto = findPhotoById(orderedPhotos, selectedAfterPhotoId) ?? defaultAfterPhoto(orderedPhotos);

        if (beforePhoto != null && afterPhoto != null && beforePhoto.id == afterPhoto.id && orderedPhotos.length > 1) {
          afterPhoto = orderedPhotos.last.id == beforePhoto.id ? orderedPhotos.first : orderedPhotos.last;
        }

        final comparisonBeforePhoto = beforePhoto;
        final comparisonAfterPhoto = afterPhoto;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.photo_camera, color: context.gymPrimary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Fotos de progreso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      ),
                      Text('${allPhotos.length} fotos', style: TextStyle(color: context.gymMutedText, fontSize: 12)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Guarda fotos frontal, lateral, espalda o libres para revisar la evolución visual.',
                    style: TextStyle(color: context.gymMutedText),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        selected: selectedCategory == 'all',
                        label: Text('Todas'),
                        onSelected: (_) => setState(() => selectedCategory = 'all'),
                      ),
                      ...progressPhotoCategories.map((category) {
                        return ChoiceChip(
                          selected: selectedCategory == category.id,
                          avatar: Icon(category.icon, size: 16),
                          label: Text(category.label),
                          onSelected: (_) => setState(() => selectedCategory = category.id),
                        );
                      }),
                    ],
                  ),
                  if (widget.allowAdd) ...[
                    SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: progressPhotoCategories.map((category) {
                        return FilledButton.icon(
                          onPressed: uploading ? null : () => upload(category.id),
                          icon: uploading
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(category.icon),
                          label: Text('Subir ${category.label.toLowerCase()}'),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 16),
            if (comparisonBeforePhoto != null && comparisonAfterPhoto != null)
              AppCard(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.compare, color: context.gymPrimary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Comparador antes / después',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '${service.formatDate(comparisonBeforePhoto.data()['createdAt'])}  →  ${service.formatDate(comparisonAfterPhoto.data()['createdAt'])}',
                      style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => selectComparisonPhoto(before: true, photos: orderedPhotos, currentSelectedId: comparisonBeforePhoto.id),
                          icon: Icon(Icons.looks_one),
                          label: Text('Antes: ${service.formatDate(comparisonBeforePhoto.data()['createdAt'])}'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => selectComparisonPhoto(before: false, photos: orderedPhotos, currentSelectedId: comparisonAfterPhoto.id),
                          icon: Icon(Icons.looks_two),
                          label: Text('Ahora: ${service.formatDate(comparisonAfterPhoto.data()['createdAt'])}'),
                        ),
                        OutlinedButton.icon(
                          onPressed: swapComparisonPhotos,
                          icon: Icon(Icons.swap_horiz),
                          label: Text('Intercambiar'),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: BeforeAfterSlider(
                          beforeImageUrl: comparisonBeforePhoto.data()['imageUrl']?.toString() ?? '',
                          afterImageUrl: comparisonAfterPhoto.data()['imageUrl']?.toString() ?? '',
                          beforeLabel: 'ANTES',
                          afterLabel: 'AHORA',
                        ),
                      ),
                    ),
                    if (widget.allowAdd) ...[
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: sharing ? null : () => shareTransformation(beforePhoto: comparisonBeforePhoto, afterPhoto: comparisonAfterPhoto),
                          icon: sharing
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(Icons.share),
                          label: Text('Compartir transformación en Comunidad'),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Sólo se publicará si confirmas. Nunca se comparte automáticamente.',
                        style: TextStyle(color: context.gymMutedText, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            if (filteredPhotos.isEmpty)
              AppCard(
                child: Text('Todavía no hay fotos para este filtro.', style: TextStyle(color: context.gymMutedText)),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 620
                      ? 2
                      : constraints.maxWidth < 1000
                          ? 3
                          : constraints.maxWidth < 1400
                              ? 4
                              : 5;
                  const spacing = 10.0;
                  final rawWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                  final width = rawWidth.clamp(160.0, 280.0).toDouble();
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: filteredPhotos.map((doc) {
                      return SizedBox(
                        width: width,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ProgressPhotoCard(
                              photoId: doc.id,
                              data: doc.data(),
                              service: service,
                              allowDelete: widget.allowAdd,
                              onDelete: () => confirmDelete(doc.id, doc.data()),
                            ),
                            if (widget.allowAdd) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      setState(() => selectedBeforePhotoId = doc.id);
                                      await persistComparisonSelection(
                                        beforePhotoId: doc.id,
                                        afterPhotoId: selectedAfterPhotoId,
                                      );
                                    },
                                    icon: Icon(selectedBeforePhotoId == doc.id ? Icons.check_circle : Icons.looks_one, size: 16),
                                    label: Text(selectedBeforePhotoId == doc.id ? 'ANTES' : 'Antes'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      setState(() => selectedAfterPhotoId = doc.id);
                                      await persistComparisonSelection(
                                        beforePhotoId: selectedBeforePhotoId,
                                        afterPhotoId: doc.id,
                                      );
                                    },
                                    icon: Icon(selectedAfterPhotoId == doc.id ? Icons.check_circle : Icons.looks_two, size: 16),
                                    label: Text(selectedAfterPhotoId == doc.id ? 'DESPUÉS' : 'Después'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}




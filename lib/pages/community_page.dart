import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../services/community_service.dart';
import '../widgets/app_card.dart';
import '../widgets/community_post_card.dart';
import '../widgets/profile_avatar.dart';
import 'community_comments_page.dart';
import 'user_profile_page.dart';

class CommunityPage extends StatelessWidget {
  final String gymId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserEmail;
  final bool trainerMode;

  const CommunityPage({
    super.key,
    required this.gymId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserEmail,
    this.trainerMode = false,
  });

  CommunityService get service => CommunityService(
        gymId: gymId,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserEmail: currentUserEmail,
      );

  void openUserProfile(
    BuildContext context, {
    required String userId,
    required String userName,
    required String userEmail,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          gymId: gymId,
          userId: userId,
          userName: userName,
          userEmail: userEmail,
        ),
      ),
    );
  }

  void openComments(BuildContext context, {required String postId, required String postTitle}) {
    final communityService = service;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityCommentsPage(
          gymId: gymId,
          postId: postId,
          postTitle: postTitle,
          currentUserId: communityService.effectiveUserId,
          currentUserName: currentUserName,
          currentUserEmail: communityService.effectiveEmail,
        ),
      ),
    );
  }

  Future<void> showLikesDialog(BuildContext context, Map<String, dynamic> data) async {
    final communityService = service;
    final users = communityService.resolvedLikeUsers(data);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.gymSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Les gusta', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                SizedBox(height: 12),
                if (users.isEmpty)
                  Text('Todavía no hay likes.', style: TextStyle(color: context.gymMutedText))
                else
                  ...users.map((user) {
                    final id = user['id'] ?? '';
                    final name = user['name'] ?? 'Usuario';
                    final email = user['email'] ?? '';
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.pop(context);
                        openUserProfile(context, userId: id, userName: name, userEmail: email);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            ProfileAvatar(name: name, size: 38),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Icon(Icons.chevron_right, color: context.gymMutedText.withValues(alpha: 0.70)),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> createManualPost(BuildContext context) async {
    final controller = TextEditingController();
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: context.gymSurface,
            title: Text('Publicar en la comunidad'),
            content: TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Mensaje',
                hintText: 'Comparte algo con la comunidad de DalaiGym...',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancelar')),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
                icon: Icon(Icons.send),
                label: Text('Publicar'),
              ),
            ],
          );
        },
      );
      if (result == null || result.isEmpty) return;
      await service.createManualPost(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publicado en la comunidad.')));
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final communityService = service;
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('Comunidad'),
        actions: [
          IconButton(
            tooltip: 'Publicar',
            onPressed: () => createManualPost(context),
            icon: Icon(Icons.add_comment),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => createManualPost(context),
        icon: Icon(Icons.edit),
        label: Text('Publicar'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: communityService.postsRef.orderBy('createdAt', descending: true).limit(50).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            final posts = snapshot.data?.docs ?? [];
            var selectedFilter = 'all';

            return StatefulBuilder(
              builder: (context, setFilterState) {
                final visiblePosts = posts.where((doc) => communityService.matchesFilter(doc.data(), selectedFilter)).toList();

                return ListView(
                  padding: EdgeInsets.all(isCompact ? 12 : 16),
                  children: [
                    AppCard(
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: context.gymFitnessAccent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.groups, color: context.gymPrimary),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Comunidad DalaiGym', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                                SizedBox(height: 3),
                                Text(
                                  'Comparte logros, retos y avances importantes con el gimnasio.',
                                  style: TextStyle(color: context.gymMutedText),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isCompact ? 10 : 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          CommunityFilterChip(text: 'Todos', selected: selectedFilter == 'all', onTap: () => setFilterState(() => selectedFilter = 'all')),
                          CommunityFilterChip(text: 'Retos', selected: selectedFilter == 'challenges', onTap: () => setFilterState(() => selectedFilter = 'challenges')),
                          CommunityFilterChip(text: 'Récords', selected: selectedFilter == 'records', onTap: () => setFilterState(() => selectedFilter = 'records')),
                          CommunityFilterChip(text: 'Objetivos', selected: selectedFilter == 'goals', onTap: () => setFilterState(() => selectedFilter = 'goals')),
                          CommunityFilterChip(text: 'Publicaciones', selected: selectedFilter == 'manual', onTap: () => setFilterState(() => selectedFilter = 'manual')),
                        ],
                      ),
                    ),
                    SizedBox(height: isCompact ? 10 : 16),
                    if (visiblePosts.isEmpty)
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Aún no hay publicaciones.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            SizedBox(height: 8),
                            Text(
                              'Cuando alguien complete un reto, consiga un logro importante o publique un mensaje, aparecerá aquí.',
                              style: TextStyle(color: context.gymMutedText),
                            ),
                          ],
                        ),
                      )
                    else
                      ...visiblePosts.map((doc) {
                        final data = doc.data();
                        final userName = data['userName']?.toString() ?? 'Usuario';
                        final postTitle = communityService.titleForPost(data);
                        final type = data['type']?.toString() ?? '';
                        final likes = communityService.likeIds(data);

                        return CommunityPostCard(
                          data: data,
                          postId: doc.id,
                          isCompact: isCompact,
                          currentUserId: communityService.effectiveUserId,
                          userName: userName,
                          dateText: communityService.formatDate(data['createdAt']),
                          postTitle: postTitle,
                          routineTitle: data['routineTitle']?.toString() ?? '',
                          message: data['message']?.toString() ?? '',
                          previewText: communityService.likesPreview(data),
                          likesTooltip: communityService.likesTooltip(data),
                          icon: communityService.iconForType(type),
                          likes: likes,
                          totalSets: data['totalSets'],
                          totalExercises: data['totalExercises'],
                          commentsCount: data['commentsCount'] ?? 0,
                          onToggleLike: () => communityService.toggleLike(doc.id, data),
                          onShowLikes: () => showLikesDialog(context, data),
                          onOpenComments: () => openComments(context, postId: doc.id, postTitle: postTitle),
                          onOpenProfile: (userId, userName, userEmail) => openUserProfile(
                            context,
                            userId: userId,
                            userName: userName,
                            userEmail: userEmail,
                          ),
                        );
                      }),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

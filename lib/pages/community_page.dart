import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/navigation_service.dart';
import '../theme/app_theme.dart';
import '../services/community_service.dart';
import '../services/subscription_service.dart';
import '../widgets/community_post_card.dart';
import '../widgets/profile_avatar.dart';
import 'community_comments_page.dart';
import 'user_profile_page.dart';
import 'subscription_upgrade_page.dart';

class CommunityPage extends StatefulWidget {
  final String gymId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserEmail;
  final bool trainerMode;
  const CommunityPage({super.key, required this.gymId, required this.currentUserId, required this.currentUserName, required this.currentUserEmail, this.trainerMode = false});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  static const int feedLimit = 25;
  String selectedFilter = 'all';
  CommunityService get service => CommunityService(gymId: widget.gymId, currentUserId: widget.currentUserId, currentUserName: widget.currentUserName, currentUserEmail: widget.currentUserEmail);
  SubscriptionService get subscriptionService => SubscriptionService(gymId: widget.gymId);
  Stream<QuerySnapshot<Map<String, dynamic>>> get feedStream => service.postsRef.orderBy('createdAt', descending: true).limit(feedLimit).snapshots();

  void openUserProfile(BuildContext context, {required String userId, required String userName, required String userEmail}) {
    AppNavigation.push(context, UserProfilePage(gymId: widget.gymId, userId: userId, userName: userName, userEmail: userEmail));
  }

  void openComments(BuildContext context, {required String postId, required String postTitle}) {
    final communityService = service;
    AppNavigation.push(context, CommunityCommentsPage(gymId: widget.gymId, postId: postId, postTitle: postTitle, currentUserId: communityService.effectiveUserId, currentUserName: widget.currentUserName, currentUserEmail: communityService.effectiveEmail));
  }

  Future<void> showLikesDialog(BuildContext context, Map<String, dynamic> data) async {
    final users = service.resolvedLikeUsers(data);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.gymSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.favorite_rounded, color: Colors.redAccent)),
                const SizedBox(width: 10),
                Expanded(child: Text('Les gusta', style: TextStyle(color: context.gymText, fontSize: 20, fontWeight: FontWeight.w900))),
              ]),
              const SizedBox(height: 14),
              if (users.isEmpty)
                Text('Todavía no hay likes.', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700))
              else
                ...users.map((user) {
                  final id = user['id'] ?? '';
                  final name = user['name'] ?? 'Usuario';
                  final email = user['email'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.pop(context);
                          openUserProfile(context, userId: id, userName: name, userEmail: email);
                        },
                        child: Ink(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(20)),
                          child: Row(children: [ProfileAvatar(name: name, size: 40), const SizedBox(width: 10), Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900))), Icon(Icons.chevron_right_rounded, color: context.gymPrimary)]),
                        ),
                      ),
                    ),
                  );
                }),
            ]),
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
            title: const Text('Publicar en la comunidad'),
            content: TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(labelText: 'Mensaje', hintText: 'Comparte algo con la comunidad de ${context.gymBrandName}...', filled: true, fillColor: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.52 : 0.72), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: context.gymPrimary.withValues(alpha: 0.55), width: 1.2))),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')), FilledButton.icon(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), icon: const Icon(Icons.send_rounded), label: const Text('Publicar'))],
          );
        },
      );
      if (result == null || result.isEmpty) return;
      await service.createManualPost(result);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publicado en la comunidad.')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo publicar: $error')));
    } finally {
      controller.dispose();
    }
  }

  Future<void> confirmAndDeletePost(String postId, Map<String, dynamic> data, String postTitle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.gymSurface,
        title: const Text('Eliminar publicación'),
        content: Text('¿Seguro que quieres eliminar "$postTitle"? Esta acción no se puede deshacer.'),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')), FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(dialogContext, true), icon: const Icon(Icons.delete_outline_rounded), label: const Text('Eliminar'))],
      ),
    );
    if (confirm != true) return;
    try {
      await service.deletePost(postId, data, trainerMode: widget.trainerMode);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publicación eliminada.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo eliminar la publicación: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final communityService = service;
    final isCompact = MediaQuery.of(context).size.width < 600;
    return StreamBuilder<GymSubscriptionPlan>(
      stream: subscriptionService.watchPlan(),
      builder: (context, planSnapshot) {
        final plan = planSnapshot.data ?? GymSubscriptionPlan.fallback(widget.gymId);
        if (!plan.isActive || !plan.communityEnabled) {
          return SubscriptionUpgradePage(gymId: widget.gymId, featureName: 'Comunidad', reason: !plan.isActive ? 'La suscripción del gimnasio no está activa.' : 'La comunidad no está incluida en el plan ${plan.plan}.');
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Comunidad'), actions: [IconButton(tooltip: 'Publicar', onPressed: () => createManualPost(context), icon: const Icon(Icons.add_comment_rounded))]),
          floatingActionButton: FloatingActionButton.extended(onPressed: () => createManualPost(context), icon: const Icon(Icons.edit_rounded), label: const Text('Publicar')),
          body: SafeArea(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: feedStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: context.gymPrimary));
                final posts = snapshot.data?.docs ?? [];
                final visiblePosts = posts.where((doc) => communityService.matchesFilter(doc.data(), selectedFilter)).toList();
                return ListView(padding: EdgeInsets.fromLTRB(isCompact ? 12 : 16, isCompact ? 12 : 16, isCompact ? 12 : 16, 96), children: [
                  _CommunityHero(totalPosts: posts.length, visiblePosts: visiblePosts.length, onPublish: () => createManualPost(context)),
                  const SizedBox(height: 12),
                  _CommunityFilterBar(selectedFilter: selectedFilter, onChanged: (value) => setState(() => selectedFilter = value)),
                  const SizedBox(height: 12),
                  if (visiblePosts.isEmpty)
                    const _CommunityEmptyState()
                  else
                    ...visiblePosts.map((doc) {
                      final data = doc.data();
                      final userName = data['userName']?.toString() ?? 'Usuario';
                      final postTitle = communityService.titleForPost(data);
                      final type = data['type']?.toString() ?? '';
                      final likes = communityService.likeIds(data);
                      return CommunityPostCard(data: data, postId: doc.id, isCompact: isCompact, currentUserId: communityService.effectiveUserId, userName: userName, dateText: communityService.formatDate(data['createdAt']), postTitle: postTitle, routineTitle: data['routineTitle']?.toString() ?? '', message: data['message']?.toString() ?? '', previewText: communityService.likesPreview(data), likesTooltip: communityService.likesTooltip(data), icon: communityService.iconForType(type), likes: likes, totalSets: data['totalSets'], totalExercises: data['totalExercises'], commentsCount: data['commentsCount'] ?? 0, canDelete: communityService.canDeletePost(data, trainerMode: widget.trainerMode), onDeletePost: () => confirmAndDeletePost(doc.id, data, postTitle), onToggleLike: () => communityService.toggleLike(doc.id, data), onShowLikes: () => showLikesDialog(context, data), onOpenComments: () => openComments(context, postId: doc.id, postTitle: postTitle), onOpenProfile: (userId, userName, userEmail) => openUserProfile(context, userId: userId, userName: userName, userEmail: userEmail));
                    }),
                  const SizedBox(height: 6),
                  Text('Mostrando las últimas ${posts.length} publicaciones.', textAlign: TextAlign.center, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                ]);
              },
            ),
          ),
        );
      },
    );
  }
}

class _CommunityHero extends StatelessWidget {
  final int totalPosts;
  final int visiblePosts;
  final VoidCallback onPublish;
  const _CommunityHero({required this.totalPosts, required this.visiblePosts, required this.onPublish});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(30)),
      child: Row(children: [
        Container(width: 50, height: 50, decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)), child: Icon(Icons.groups_rounded, color: context.gymPrimary, size: 27)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Comunidad ${context.gymBrandName}', style: TextStyle(color: context.gymText, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.3)), const SizedBox(height: 4), Text('$visiblePosts visibles · $totalPosts recientes', style: TextStyle(color: context.gymMutedText, fontSize: 12.5, fontWeight: FontWeight.w800))])),
        TextButton.icon(onPressed: onPublish, icon: const Icon(Icons.edit_rounded), label: const Text('Publicar')),
      ]),
    );
  }
}

class _CommunityFilterBar extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onChanged;
  const _CommunityFilterBar({required this.selectedFilter, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), child: Row(children: [CommunityFilterChip(text: 'Todos', selected: selectedFilter == 'all', onTap: () => onChanged('all')), CommunityFilterChip(text: 'Retos', selected: selectedFilter == 'challenges', onTap: () => onChanged('challenges')), CommunityFilterChip(text: 'Récords', selected: selectedFilter == 'records', onTap: () => onChanged('records')), CommunityFilterChip(text: 'Objetivos', selected: selectedFilter == 'goals', onTap: () => onChanged('goals')), CommunityFilterChip(text: 'Publicaciones', selected: selectedFilter == 'manual', onTap: () => onChanged('manual'))]));
  }
}

class _CommunityEmptyState extends StatelessWidget {
  const _CommunityEmptyState();
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(28)), child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [Container(width: 54, height: 54, decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(22)), child: Icon(Icons.forum_rounded, color: context.gymPrimary, size: 30)), const SizedBox(height: 12), Text('Aún no hay publicaciones', textAlign: TextAlign.center, style: TextStyle(color: context.gymText, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text('Cuando alguien complete un reto, consiga un logro importante o publique un mensaje, aparecerá aquí.', textAlign: TextAlign.center, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700))]));
  }
}

class _SubscriptionLockedPage extends StatelessWidget {
  final String featureName;
  final String reason;
  const _SubscriptionLockedPage({required this.featureName, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(featureName)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 42, color: context.gymPrimary),
                  const SizedBox(height: 12),
                  Text(
                    '$featureName bloqueado',
                    style: TextStyle(color: context.gymText, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

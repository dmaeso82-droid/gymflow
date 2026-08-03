
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/profile_avatar.dart';

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

  CollectionReference<Map<String, dynamic>> get postsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('community_posts');

  String get effectiveUserId => currentUserId.isNotEmpty
      ? currentUserId
      : (FirebaseAuth.instance.currentUser?.uid ?? 'anonymous');

  String get effectiveEmail => currentUserEmail.isNotEmpty
      ? currentUserEmail.toLowerCase()
      : (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase();

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month · $hour:$minute';
    }
    return 'Fecha pendiente';
  }

  IconData iconForType(String type) {
    switch (type) {
      case 'workout_completed':
        return Icons.fitness_center;
      case 'personal_record':
        return Icons.emoji_events;
      case 'goal_completed':
        return Icons.flag;
      case 'measurement_update':
        return Icons.monitor_weight;
      default:
        return Icons.forum;
    }
  }

  String titleForPost(Map<String, dynamic> data) {
    final title = data['title']?.toString().trim();
    if (title != null && title.isNotEmpty) return title;
    final type = data['type']?.toString() ?? '';
    switch (type) {
      case 'workout_completed':
        return 'Entrenamiento completado';
      case 'personal_record':
        return 'Nuevo récord personal';
      case 'goal_completed':
        return 'Objetivo completado';
      case 'measurement_update':
        return 'Progreso físico actualizado';
      default:
        return 'Publicación';
    }
  }

  Future<void> toggleLike(String postId, List<dynamic> likes) async {
    final uid = effectiveUserId;
    if (likes.contains(uid)) {
      await postsRef.doc(postId).update({
        'likes': FieldValue.arrayRemove([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await postsRef.doc(postId).update({
        'likes': FieldValue.arrayUnion([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void openComments(
    BuildContext context, {
    required String postId,
    required String postTitle,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityCommentsPage(
          gymId: gymId,
          postId: postId,
          postTitle: postTitle,
          currentUserId: effectiveUserId,
          currentUserName: currentUserName,
          currentUserEmail: effectiveEmail,
        ),
      ),
    );
  }

  Future<void> createManualPost(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Publicar en la comunidad'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Mensaje',
              hintText: 'Comparte algo con la comunidad de DalaiGym...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              icon: const Icon(Icons.send),
              label: const Text('Publicar'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;

    await postsRef.add({
      'type': 'manual_post',
      'userId': effectiveUserId,
      'userName': currentUserName,
      'userEmail': effectiveEmail,
      'title': 'Publicación de comunidad',
      'message': result,
      'likes': [],
      'commentsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicado en la comunidad.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comunidad'),
        actions: [
          IconButton(
            tooltip: 'Publicar',
            onPressed: () => createManualPost(context),
            icon: const Icon(Icons.add_comment),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => createManualPost(context),
        icon: const Icon(Icons.edit),
        label: const Text('Publicar'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: postsRef.orderBy('createdAt', descending: true).limit(50).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final posts = snapshot.data?.docs ?? [];
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
                          color: Colors.greenAccent.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.groups, color: Colors.greenAccent),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Comunidad DalaiGym',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Comparte entrenamientos, logros y avances con el gimnasio.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isCompact ? 10 : 16),
                if (posts.isEmpty)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Aún no hay publicaciones.',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Cuando un usuario comparta un entrenamiento o alguien publique un mensaje, aparecerá aquí.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                else
                  ...posts.map((doc) {
                    final data = doc.data();
                    final userName = data['userName']?.toString() ?? 'Usuario';
                    final message = data['message']?.toString() ?? '';
                    final routineTitle = data['routineTitle']?.toString() ?? '';
                    final type = data['type']?.toString() ?? '';
                    final likes = List<dynamic>.from(data['likes'] ?? []);
                    final liked = likes.contains(effectiveUserId);
                    final totalSets = data['totalSets'];
                    final totalExercises = data['totalExercises'];
                    final commentsCount = data['commentsCount'] ?? 0;
                    final dateText = formatDate(data['createdAt']);
                    final postTitle = titleForPost(data);

                    return AppCard(
                      margin: EdgeInsets.only(bottom: isCompact ? 10 : 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ProfileAvatar(name: userName, size: isCompact ? 42 : 48),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateText,
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(iconForType(type), color: Colors.greenAccent, size: 22),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            postTitle,
                            style: TextStyle(fontSize: isCompact ? 17 : 18, fontWeight: FontWeight.w900),
                          ),
                          if (routineTitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              routineTitle,
                              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w700),
                            ),
                          ],
                          if (message.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(message, style: const TextStyle(color: Colors.white70)),
                          ],
                          if (totalSets != null || totalExercises != null) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (totalSets != null) _CommunityChip(text: '$totalSets series'),
                                if (totalExercises != null) _CommunityChip(text: '$totalExercises ejercicios'),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () => toggleLike(doc.id, likes),
                                icon: Icon(
                                  liked ? Icons.favorite : Icons.favorite_border,
                                  color: liked ? Colors.redAccent : Colors.white70,
                                  size: 20,
                                ),
                                label: Text('${likes.length}'),
                              ),
                              TextButton.icon(
                                onPressed: () => openComments(
                                  context,
                                  postId: doc.id,
                                  postTitle: postTitle,
                                ),
                                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                label: Text('$commentsCount'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CommunityCommentsPage extends StatefulWidget {
  final String gymId;
  final String postId;
  final String postTitle;
  final String currentUserId;
  final String currentUserName;
  final String currentUserEmail;

  const CommunityCommentsPage({
    super.key,
    required this.gymId,
    required this.postId,
    required this.postTitle,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserEmail,
  });

  @override
  State<CommunityCommentsPage> createState() => _CommunityCommentsPageState();
}

class _CommunityCommentsPageState extends State<CommunityCommentsPage> {
  final controller = TextEditingController();
  bool sending = false;

  DocumentReference<Map<String, dynamic>> get postRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('community_posts')
      .doc(widget.postId);

  CollectionReference<Map<String, dynamic>> get commentsRef => postRef.collection('comments');

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month · $hour:$minute';
    }
    return 'Fecha pendiente';
  }

  Future<void> sendComment() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await commentsRef.add({
        'userId': widget.currentUserId,
        'userName': widget.currentUserName,
        'userEmail': widget.currentUserEmail.toLowerCase(),
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await postRef.update({
        'commentsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      controller.clear();
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      appBar: AppBar(title: const Text('Comentarios')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(isCompact ? 12 : 16, isCompact ? 12 : 16, isCompact ? 12 : 16, 0),
              child: AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.greenAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.postTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: commentsRef.orderBy('createdAt', descending: false).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final comments = snapshot.data?.docs ?? [];
                  if (comments.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aún no hay comentarios. Sé el primero en comentar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: EdgeInsets.all(isCompact ? 12 : 16),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final data = comments[index].data();
                      final userName = data['userName']?.toString() ?? 'Usuario';
                      final text = data['text']?.toString() ?? '';
                      final date = formatDate(data['createdAt']);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProfileAvatar(name: userName, size: 38),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          userName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                      Text(date, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(text, style: const TextStyle(color: Colors.white70)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(isCompact ? 12 : 16, 10, isCompact ? 12 : 16, isCompact ? 12 : 16),
              decoration: const BoxDecoration(
                color: Color(0xFF020617),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un comentario...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: sending ? null : sendComment,
                    child: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
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

class _CommunityChip extends StatelessWidget {
  final String text;
  const _CommunityChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.22)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

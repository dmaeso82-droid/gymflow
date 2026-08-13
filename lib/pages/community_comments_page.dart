import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../services/notification_service.dart';
import '../widgets/app_card.dart';
import '../widgets/profile_avatar.dart';
import 'user_profile_page.dart';

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

  void openUserProfile(BuildContext context, Map<String, dynamic> data, String userName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          gymId: widget.gymId,
          userId: data['userId']?.toString() ?? '',
          userName: userName,
          userEmail: data['userEmail']?.toString() ?? '',
        ),
      ),
    );
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

      final postSnapshot = await postRef.get();
      final postData = postSnapshot.data() ?? {};

      await postRef.update({
        'commentsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final ownerId = postData['userId']?.toString() ?? '';
      final ownerEmail = (postData['userEmail'] ?? '').toString();
      final isOwnPost = (ownerId.isNotEmpty && ownerId == widget.currentUserId) ||
          (ownerEmail.isNotEmpty &&
              ownerEmail.toLowerCase() == widget.currentUserEmail.toLowerCase());

      if (!isOwnPost) {
        await NotificationService(gymId: widget.gymId).createNotification(
          userId: ownerId,
          userEmail: ownerEmail,
          type: 'post_comment',
          title: 'Nuevo comentario',
          message: '${widget.currentUserName} ha comentado tu publicación.',
          sourceId: widget.postId,
        );
      }

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
      appBar: AppBar(title: Text('Comentarios')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(isCompact ? 12 : 16, isCompact ? 12 : 16, isCompact ? 12 : 16, 0),
              child: AppCard(
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: context.gymPrimary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.postTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
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
                    return Center(child: CircularProgressIndicator());
                  }

                  final comments = snapshot.data?.docs ?? [];
                  if (comments.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aún no hay comentarios. Sé el primero en comentar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.gymMutedText),
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
                          color: context.gymSubtleSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: context.gymBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => openUserProfile(context, data, userName),
                              child: ProfileAvatar(name: userName, size: 38),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => openUserProfile(context, data, userName),
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
                                            style: TextStyle(fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                        Text(date, style: TextStyle(color: context.gymMutedText.withValues(alpha: 0.85), fontSize: 11)),
                                      ],
                                    ),
                                    SizedBox(height: 6),
                                    Text(text, style: TextStyle(color: context.gymMutedText)),
                                  ],
                                ),
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
              decoration: BoxDecoration(
                color: context.gymSubtleSurface,
                border: Border(top: BorderSide(color: context.gymBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Escribe un comentario...',
                        filled: true,
                        fillColor: context.gymSubtleSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        isDense: true,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  FilledButton(
                    onPressed: sending ? null : sendComment,
                    child: sending
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Icons.send),
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




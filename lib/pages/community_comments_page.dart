import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
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

  DocumentReference<Map<String, dynamic>> get postRef => FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('community_posts').doc(widget.postId);
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
      await postRef.update({'commentsCount': FieldValue.increment(1), 'updatedAt': FieldValue.serverTimestamp()});
      final ownerId = postData['userId']?.toString() ?? '';
      final ownerEmail = (postData['userEmail'] ?? '').toString();
      final isOwnPost = (ownerId.isNotEmpty && ownerId == widget.currentUserId) || (ownerEmail.isNotEmpty && ownerEmail.toLowerCase() == widget.currentUserEmail.toLowerCase());
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
      appBar: AppBar(title: const Text('Comentarios')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(isCompact ? 12 : 16, isCompact ? 12 : 16, isCompact ? 12 : 16, 0),
              child: _CommentsHeader(icon: Icons.forum_rounded, title: widget.postTitle, subtitle: 'Conversación de la comunidad'),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: commentsRef.orderBy('createdAt', descending: false).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: context.gymPrimary));
                  final comments = snapshot.data?.docs ?? [];
                  if (comments.isEmpty) return const _CommentsEmptyState(text: 'Aún no hay comentarios. Sé el primero en comentar.');
                  return ListView.builder(
                    padding: EdgeInsets.all(isCompact ? 12 : 16),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final data = comments[index].data();
                      final userName = data['userName']?.toString() ?? 'Usuario';
                      final text = data['text']?.toString() ?? '';
                      final date = formatDate(data['createdAt']);
                      return _CommentBubble(
                        userName: userName,
                        date: date,
                        text: text,
                        onTap: () => openUserProfile(context, data, userName),
                      );
                    },
                  );
                },
              ),
            ),
            _CommentComposer(controller: controller, sending: sending, onSend: sendComment),
          ],
        ),
      ),
    );
  }
}

class _CommentsHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CommentsHeader({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(26)),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(17)), child: Icon(icon, color: context.gymPrimary, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  final String userName;
  final String date;
  final String text;
  final VoidCallback onTap;

  const _CommentBubble({required this.userName, required this.date, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
            decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.46 : 0.68), borderRadius: BorderRadius.circular(22)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ProfileAvatar(name: userName, size: 40),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900))),
                  Text(date, style: TextStyle(color: context.gymMutedText.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 6),
                Text(text, style: TextStyle(color: context.gymMutedText, height: 1.32, fontWeight: FontWeight.w600)),
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CommentsEmptyState extends StatelessWidget {
  final String text;

  const _CommentsEmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 54, height: 54, decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(22)), child: Icon(Icons.chat_bubble_outline_rounded, color: context.gymPrimary, size: 28)),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _CommentComposer({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.fromLTRB(isCompact ? 12 : 16, 10, isCompact ? 12 : 16, isCompact ? 12 : 16),
      decoration: BoxDecoration(color: context.gymSurface.withValues(alpha: context.gymIsDark ? 0.88 : 0.96), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: context.gymIsDark ? 0.20 : 0.06), blurRadius: 20, spreadRadius: -12, offset: const Offset(0, -8))]),
      child: Row(children: [
        Expanded(child: TextField(controller: controller, minLines: 1, maxLines: 4, decoration: InputDecoration(hintText: 'Escribe un comentario...', filled: true, fillColor: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.54 : 0.76), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: context.gymPrimary.withValues(alpha: 0.55), width: 1.2)), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)))) ,
        const SizedBox(width: 10),
        SizedBox(width: 48, height: 48, child: FilledButton(style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero), onPressed: sending ? null : onSend, child: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded))),
      ]),
    );
  }
}

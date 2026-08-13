
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../widgets/app_card.dart';
import '../widgets/profile_avatar.dart';

class RoutineCommentsPage extends StatefulWidget {
  final String gymId;
  final String routineId;
  final String routineTitle;
  final String currentUserId;
  final String currentUserName;
  final String currentUserEmail;
  final String currentUserRole;

  const RoutineCommentsPage({
    super.key,
    required this.gymId,
    required this.routineId,
    required this.routineTitle,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserEmail,
    this.currentUserRole = 'client',
  });

  @override
  State<RoutineCommentsPage> createState() => _RoutineCommentsPageState();
}

class _RoutineCommentsPageState extends State<RoutineCommentsPage> {
  final controller = TextEditingController();
  bool sending = false;

  DocumentReference<Map<String, dynamic>> get routineRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('routines')
      .doc(widget.routineId);

  CollectionReference<Map<String, dynamic>> get commentsRef => routineRef.collection('comments');

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
        'role': widget.currentUserRole,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await routineRef.set({
        'commentsCount': FieldValue.increment(1),
        'lastCommentAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
                        widget.routineTitle,
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
                          'Aún no hay comentarios en esta rutina.',
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
                      final role = data['role']?.toString() ?? 'client';
                      final roleLabel = role == 'trainer' ? 'Entrenador' : 'Cliente';
                      final roleIcon = role == 'trainer' ? Icons.school : Icons.fitness_center;
                      final roleColor = role == 'trainer' ? Colors.amberAccent : context.gymPrimary;
                      final date = formatDate(data['createdAt']);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.gymSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: context.gymBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProfileAvatar(name: userName, size: 38),
                            SizedBox(width: 10),
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
                                          style: TextStyle(fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                      Text(date, style: TextStyle(color: context.gymMutedText, fontSize: 11)),
                                    ],
                                  ),
                                  SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: roleColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: roleColor.withValues(alpha: 0.25)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(roleIcon, size: 13, color: roleColor),
                                        SizedBox(width: 4),
                                        Text(
                                          roleLabel,
                                          style: TextStyle(
                                            color: roleColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(text, style: TextStyle(color: context.gymMutedText)),
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
              decoration: BoxDecoration(
                color: context.gymSurface,
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
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  FilledButton(
                    onPressed: sending ? null : sendComment,
                    child: sending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
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




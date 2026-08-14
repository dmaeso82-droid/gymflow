import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/chat_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/profile_avatar.dart';

class ChatPage extends StatefulWidget {
  final String gymId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserEmail;
  final String currentRole;
  final String otherUserId;
  final String otherUserName;
  final String otherUserEmail;
  final String otherRole;

  const ChatPage({
    super.key,
    required this.gymId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserEmail,
    required this.currentRole,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserEmail,
    required this.otherRole,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final controller = TextEditingController();
  String? conversationId;
  bool loading = true;

  ChatService get service => ChatService(
        gymId: widget.gymId,
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
        currentUserEmail: widget.currentUserEmail,
      );

  @override
  void initState() {
    super.initState();
    initialiseConversation();
  }

  Future<void> initialiseConversation() async {
    final id = await service.ensureConversation(
      otherUserId: widget.otherUserId,
      otherUserName: widget.otherUserName,
      otherUserEmail: widget.otherUserEmail,
      otherRole: widget.otherRole,
      currentRole: widget.currentRole,
    );
    await service.markRead(id);
    if (mounted) {
      setState(() {
        conversationId = id;
        loading = false;
      });
    }
  }

  Future<void> send() async {
    final id = conversationId;
    if (id == null) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;
    controller.clear();
    await service.sendMessage(
      conversationId: id,
      text: text,
      otherUserId: widget.otherUserId,
      otherUserEmail: widget.otherUserEmail,
    );
  }

  String roleLabel(String role) {
    if (role == 'trainer') return 'Entrenador';
    return 'Cliente';
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = conversationId;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            ProfileAvatar(name: widget.otherUserName, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.otherUserName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.gymPrimary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: context.gymPrimary.withValues(alpha: 0.16)),
                        ),
                        child: Text(roleLabel(widget.otherRole), style: TextStyle(color: context.gymPrimary, fontSize: 10.5, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: loading || id == null
            ? Center(child: CircularProgressIndicator(color: context.gymPrimary))
            : Column(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: service.messagesRef(id).orderBy('createdAt', descending: true).limit(100).snapshots(),
                      builder: (context, snapshot) {
                        final messages = snapshot.data?.docs ?? [];
                        if (messages.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: context.gymSubtleSurface,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: context.gymBorder),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.chat_bubble_outline_rounded, color: context.gymPrimary, size: 34),
                                    const SizedBox(height: 10),
                                    Text('Todavía no hay mensajes', style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text('Escribe el primero para iniciar la conversación.', textAlign: TextAlign.center, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final data = messages[index].data();
                            final senderId = data['senderId']?.toString() ?? '';
                            final senderEmail = (data['senderEmail'] ?? '').toString().toLowerCase();
                            final isMine = (widget.currentUserId.isNotEmpty && senderId == widget.currentUserId) ||
                                (widget.currentUserEmail.isNotEmpty && senderEmail == widget.currentUserEmail.toLowerCase());
                            return MessageBubble(data: data, isMine: isMine);
                          },
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
                              hintText: 'Escribe un mensaje...',
                              filled: true,
                              fillColor: context.gymSubtleSurface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: context.gymBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: context.gymBorder)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: context.gymPrimary.withValues(alpha: 0.72), width: 1.4)),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            onSubmitted: (_) => send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
                            onPressed: send,
                            child: const Icon(Icons.send_rounded),
                          ),
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

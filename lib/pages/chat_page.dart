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
  ChatService get service => ChatService(gymId: widget.gymId, currentUserId: widget.currentUserId, currentUserName: widget.currentUserName, currentUserEmail: widget.currentUserEmail);
  @override
  void initState() {
    super.initState();
    initialiseConversation();
  }
  Future<void> initialiseConversation() async {
    final id = await service.ensureConversation(otherUserId: widget.otherUserId, otherUserName: widget.otherUserName, otherUserEmail: widget.otherUserEmail, otherRole: widget.otherRole, currentRole: widget.currentRole);
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
    await service.sendMessage(conversationId: id, text: text, otherUserId: widget.otherUserId, otherUserEmail: widget.otherUserEmail);
  }
  String roleLabel(String role) => role == 'trainer' ? 'Entrenador' : 'Cliente';
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
        title: Row(children: [
          ProfileAvatar(name: widget.otherUserName, size: 38),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(widget.otherUserName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(roleLabel(widget.otherRole), style: TextStyle(color: context.gymPrimary, fontSize: 11, fontWeight: FontWeight.w900)),
          ])),
        ]),
      ),
      body: SafeArea(
        child: loading || id == null
            ? Center(child: CircularProgressIndicator(color: context.gymPrimary))
            : Column(children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: service.messagesRef(id).orderBy('createdAt', descending: true).limit(100).snapshots(),
                    builder: (context, snapshot) {
                      final messages = snapshot.data?.docs ?? [];
                      if (messages.isEmpty) return _EmptyChat(otherName: widget.otherUserName);
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final data = messages[index].data();
                          final senderId = data['senderId']?.toString() ?? '';
                          final senderEmail = (data['senderEmail'] ?? '').toString().toLowerCase();
                          final isMine = (widget.currentUserId.isNotEmpty && senderId == widget.currentUserId) || (widget.currentUserEmail.isNotEmpty && senderEmail == widget.currentUserEmail.toLowerCase());
                          return MessageBubble(data: data, isMine: isMine);
                        },
                      );
                    },
                  ),
                ),
                _ChatComposer(controller: controller, onSend: send),
              ]),
      ),
    );
  }
}
class _EmptyChat extends StatelessWidget {
  final String otherName;
  const _EmptyChat({required this.otherName});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 58, height: 58, decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(22)), child: Icon(Icons.chat_bubble_outline_rounded, color: context.gymPrimary, size: 30)),
          const SizedBox(height: 12),
          Text('Conversación con $otherName', textAlign: TextAlign.center, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 6),
          Text('Escribe el primer mensaje para iniciar el seguimiento.', textAlign: TextAlign.center, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
class _ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _ChatComposer({required this.controller, required this.onSend});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(color: context.gymSurface.withValues(alpha: context.gymIsDark ? 0.88 : 0.96), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: context.gymIsDark ? 0.20 : 0.06), blurRadius: 20, spreadRadius: -12, offset: const Offset(0, -8))]),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Escribe un mensaje...',
              filled: true,
              fillColor: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.54 : 0.76),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: context.gymPrimary.withValues(alpha: 0.55), width: 1.2)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onSubmitted: (_) => onSend(),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 48, height: 48, child: FilledButton(style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero), onPressed: onSend, child: const Icon(Icons.send_rounded))),
      ]),
    );
  }
}

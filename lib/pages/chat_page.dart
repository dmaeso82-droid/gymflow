import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../services/chat_service.dart';
import '../widgets/message_bubble.dart';

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

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = conversationId;

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherUserName)),
      body: SafeArea(
        child: loading || id == null
            ? Center(child: CircularProgressIndicator())
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
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Todavía no hay mensajes. Escribe el primero.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: context.gymMutedText),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(12),
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
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => send(),
                          ),
                        ),
                        SizedBox(width: 8),
                        FilledButton(onPressed: send, child: Icon(Icons.send)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}




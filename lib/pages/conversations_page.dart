import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/chat_service.dart';
import '../widgets/app_card.dart';
import '../widgets/profile_avatar.dart';
import 'chat_page.dart';

class ConversationsPage extends StatelessWidget {
  final String gymId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserEmail;
  final String currentRole;

  const ConversationsPage({
    super.key,
    required this.gymId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserEmail,
    required this.currentRole,
  });

  ChatService get service => ChatService(
        gymId: gymId,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserEmail: currentUserEmail,
      );

  void openChat(BuildContext context, ChatParticipant other) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          gymId: gymId,
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          currentUserEmail: currentUserEmail,
          currentRole: currentRole,
          otherUserId: other.id,
          otherUserName: other.name,
          otherUserEmail: other.email,
          otherRole: other.role,
        ),
      ),
    );
  }

  String roleLabel(String role) {
    if (role == 'trainer') return 'Entrenador';
    return 'Cliente';
  }

  String formatTime(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month · $hour:$minute';
    }
    return '';
  }

  Future<void> startConversation(BuildContext context) async {
    final chatService = service;
    final options = currentRole == 'trainer' ? await chatService.loadClients() : await chatService.loadTrainers();
    if (!context.mounted) return;
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(currentRole == 'trainer' ? 'No hay clientes disponibles.' : 'No hay entrenadores disponibles.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<ChatParticipant>(
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
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.gymPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.add_comment_rounded, color: context.gymPrimary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        currentRole == 'trainer' ? 'Iniciar chat con cliente' : 'Iniciar chat con entrenador',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: context.gymText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final user = options[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: context.gymSubtleSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: context.gymBorder),
                        ),
                        child: ListTile(
                          leading: ProfileAvatar(name: user.name, size: 40),
                          title: Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.gymMutedText),
                          ),
                          trailing: Icon(Icons.chevron_right, color: context.gymMutedText.withValues(alpha: 0.70)),
                          onTap: () => Navigator.pop(context, user),
                        ),
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

    if (selected != null && context.mounted) {
      openChat(context, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatService = service;
    final key = currentUserId.isNotEmpty ? currentUserId : currentUserEmail.toLowerCase();
    return Scaffold(
      appBar: AppBar(title: const Text('Mensajes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => startConversation(context),
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('Nuevo chat'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: chatService.conversationsRef
              .where(currentUserId.isNotEmpty ? 'participantIds' : 'participantEmails', arrayContains: key)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: context.gymPrimary));
            }
            final conversations = snapshot.data?.docs ?? [];
            conversations.sort((a, b) {
              final aDate = a.data()['lastMessageAt'];
              final bDate = b.data()['lastMessageAt'];
              final aMs = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
              final bMs = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;
              return bMs.compareTo(aMs);
            });

            if (conversations.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        Icon(Icons.mark_chat_unread_outlined, color: context.gymPrimary, size: 34),
                        const SizedBox(height: 10),
                        Text('Todavía no tienes conversaciones', style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900, fontSize: 17)),
                        const SizedBox(height: 4),
                        Text('Pulsa "Nuevo chat" para iniciar una conversación.', textAlign: TextAlign.center, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final doc = conversations[index];
                final data = doc.data();
                final other = chatService.otherParticipant(data);
                final lastMessage = data['lastMessage']?.toString() ?? 'Sin mensajes todavía';
                final time = formatTime(data['lastMessageAt']);
                final unread = chatService.isUnread(data);

                return AppCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  radius: 22,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => openChat(context, other),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ProfileAvatar(name: other.name, size: 48),
                            if (unread)
                              Positioned(
                                right: -1,
                                top: -1,
                                child: Container(
                                  width: 13,
                                  height: 13,
                                  decoration: BoxDecoration(
                                    color: context.gymPrimary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: context.gymSurface, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      other.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: unread ? context.gymPrimary : context.gymText),
                                    ),
                                  ),
                                  if (time.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: context.gymSubtleSurface,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: context.gymBorder.withValues(alpha: 0.7)),
                                      ),
                                      child: Text(time, style: TextStyle(color: context.gymMutedText, fontSize: 10.5, fontWeight: FontWeight.w800)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: context.gymPrimary.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: context.gymPrimary.withValues(alpha: 0.16)),
                                    ),
                                    child: Text(roleLabel(other.role), style: TextStyle(color: context.gymPrimary, fontSize: 10, fontWeight: FontWeight.w900)),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      lastMessage,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: unread ? context.gymText : context.gymMutedText, fontWeight: unread ? FontWeight.w800 : FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

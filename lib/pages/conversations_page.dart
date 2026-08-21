import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/chat_service.dart';
import '../widgets/profile_avatar.dart';
import 'chat_page.dart';
import 'subscription_upgrade_page.dart';

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

  ChatService get service => ChatService(gymId: gymId, currentUserId: currentUserId, currentUserName: currentUserName, currentUserEmail: currentUserEmail);

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

  String roleLabel(String role) => role == 'trainer' ? 'Entrenador' : 'Cliente';

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(currentRole == 'trainer' ? 'No hay clientes disponibles.' : 'No hay entrenadores disponibles.')));
      return;
    }
    final selected = await showModalBottomSheet<ChatParticipant>(
      context: context,
      backgroundColor: context.gymSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(17)), child: Icon(Icons.add_comment_rounded, color: context.gymPrimary)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(currentRole == 'trainer' ? 'Iniciar chat con cliente' : 'Iniciar chat con entrenador', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: context.gymText))),
                ]),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final user = options[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => Navigator.pop(context, user),
                            child: Ink(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(20)),
                              child: Row(children: [
                                ProfileAvatar(name: user.name, size: 40),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 2),
                                  Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                                ])),
                                Icon(Icons.chevron_right_rounded, color: context.gymPrimary),
                              ]),
                            ),
                          ),
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
    if (selected != null && context.mounted) openChat(context, selected);
  }

  @override
  Widget build(BuildContext context) {
    final chatService = service;
    final key = currentUserId.isNotEmpty ? currentUserId : currentUserEmail.toLowerCase();
    return SubscriptionFeatureGate(
      gymId: gymId,
      featureKey: 'chat',
      featureName: 'Chat',
      upgradeReason: 'El chat está disponible en el plan Pro y Enterprise.',
      child: Scaffold(
      appBar: AppBar(title: const Text('Mensajes')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => startConversation(context), icon: const Icon(Icons.add_comment_rounded), label: const Text('Nuevo chat')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: chatService.conversationsRef.where(currentUserId.isNotEmpty ? 'participantIds' : 'participantEmails', arrayContains: key).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: context.gymPrimary));
            final conversations = snapshot.data?.docs ?? [];
            conversations.sort((a, b) {
              final aDate = a.data()['lastMessageAt'];
              final bDate = b.data()['lastMessageAt'];
              final aMs = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
              final bMs = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;
              return bMs.compareTo(aMs);
            });
            if (conversations.isEmpty) return _EmptyConversations(onStart: () => startConversation(context));
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 92),
              itemCount: conversations.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _MessagesHeader(count: conversations.length, onStart: () => startConversation(context));
                final doc = conversations[index - 1];
                final data = doc.data();
                final other = chatService.otherParticipant(data);
                final lastMessage = data['lastMessage']?.toString() ?? 'Sin mensajes todavía';
                final time = formatTime(data['lastMessageAt']);
                final unread = chatService.isUnread(data);
                return _ConversationRow(other: other, lastMessage: lastMessage, time: time, unread: unread, roleLabel: roleLabel(other.role), onTap: () => openChat(context, other));
              },
            );
          },
        ),
      ),
    ),
    );
  }
}

class _MessagesHeader extends StatelessWidget {
  final int count;
  final VoidCallback onStart;
  const _MessagesHeader({required this.count, required this.onStart});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Conversaciones', style: TextStyle(color: context.gymText, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text('$count chat${count == 1 ? '' : 's'} activo${count == 1 ? '' : 's'}', style: TextStyle(color: context.gymMutedText, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ])),
        TextButton.icon(onPressed: onStart, icon: const Icon(Icons.add_rounded), label: const Text('Nuevo')),
      ]),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  final ChatParticipant other;
  final String lastMessage;
  final String time;
  final bool unread;
  final String roleLabel;
  final VoidCallback onTap;
  const _ConversationRow({required this.other, required this.lastMessage, required this.time, required this.unread, required this.roleLabel, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.46 : 0.68), borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              Stack(clipBehavior: Clip.none, children: [
                ProfileAvatar(name: other.name, size: 48),
                if (unread) Positioned(right: -1, top: -1, child: Container(width: 13, height: 13, decoration: BoxDecoration(color: context.gymPrimary, shape: BoxShape.circle, border: Border.all(color: context.gymSurface, width: 2)))),
              ]),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(other.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: unread ? context.gymPrimary : context.gymText))),
                  if (time.isNotEmpty) Text(time, style: TextStyle(color: context.gymMutedText, fontSize: 10.5, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 5),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)), child: Text(roleLabel, style: TextStyle(color: context.gymPrimary, fontSize: 10, fontWeight: FontWeight.w900))),
                  const SizedBox(width: 7),
                  Expanded(child: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: unread ? context.gymText : context.gymMutedText, fontWeight: unread ? FontWeight.w800 : FontWeight.w600))),
                ]),
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  final VoidCallback onStart;
  const _EmptyConversations({required this.onStart});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 58, height: 58, decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(22)), child: Icon(Icons.mark_chat_unread_outlined, color: context.gymPrimary, size: 30)),
          const SizedBox(height: 12),
          Text('Todavía no tienes conversaciones', textAlign: TextAlign.center, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 6),
          Text('Inicia un chat para coordinar rutinas, dudas o seguimiento.', textAlign: TextAlign.center, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.add_comment_rounded), label: const Text('Nuevo chat')),
        ]),
      ),
    );
  }
}

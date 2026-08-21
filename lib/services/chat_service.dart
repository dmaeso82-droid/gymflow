import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import 'subscription_service.dart';
class ChatParticipant {
  final String id;
  final String name;
  final String email;
  final String role;
  const ChatParticipant({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });
}
class ChatService {
  final String gymId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserEmail;
  const ChatService({
    required this.gymId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserEmail,
  });
  SubscriptionService get subscriptionService => SubscriptionService(gymId: gymId);

  CollectionReference<Map<String, dynamic>> get conversationsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('conversations');
  CollectionReference<Map<String, dynamic>> get clientsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('clients');
  CollectionReference<Map<String, dynamic>> get trainersRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('trainers');
  String conversationIdFor(String otherUserId, String otherEmail) {
    final me = currentUserId.trim().isNotEmpty
        ? currentUserId.trim()
        : currentUserEmail.trim().toLowerCase();
    final other = otherUserId.trim().isNotEmpty
        ? otherUserId.trim()
        : otherEmail.trim().toLowerCase();
    if (me.isEmpty || other.isEmpty || me == other) {
      throw ArgumentError('No se puede crear una conversación con estos participantes.');
    }
    final ids = [me, other]..sort();
    return ids.join('_');
  }
  DocumentReference<Map<String, dynamic>> conversationRef(String conversationId) {
    return conversationsRef.doc(conversationId);
  }
  CollectionReference<Map<String, dynamic>> messagesRef(String conversationId) {
    return conversationRef(conversationId).collection('messages');
  }
  Future<List<ChatParticipant>> loadClients() async {
    await subscriptionService.assertActive(feature: 'chat');
    final snapshot = await clientsRef.orderBy('name').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final authUid = data['authUid']?.toString() ?? '';
      return ChatParticipant(
        id: authUid.isNotEmpty ? authUid : doc.id,
        name: data['name']?.toString() ?? 'Cliente',
        email: (data['email'] ?? '').toString().toLowerCase(),
        role: 'user',
      );
    }).where((item) => item.email.isNotEmpty).toList();
  }
  Future<List<ChatParticipant>> loadTrainers() async {
    await subscriptionService.assertActive(feature: 'chat');
    final snapshot = await trainersRef.orderBy('name').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return ChatParticipant(
        id: doc.id,
        name: data['name']?.toString() ?? 'Entrenador',
        email: (data['email'] ?? '').toString().toLowerCase(),
        role: 'trainer',
      );
    }).where((item) => item.email.isNotEmpty).toList();
  }
  Future<String> ensureConversation({
    required String otherUserId,
    required String otherUserName,
    required String otherUserEmail,
    required String otherRole,
    required String currentRole,
  }) async {
    final conversationId = conversationIdFor(otherUserId, otherUserEmail);
    final ref = conversationRef(conversationId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final payload = <String, dynamic>{
        'participantIds': [currentUserId.trim(), otherUserId.trim()]
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList(),
        'participantEmails': [
          currentUserEmail.trim().toLowerCase(),
          otherUserEmail.trim().toLowerCase(),
        ].where((item) => item.isNotEmpty).toSet().toList(),
        'participants': {
          currentUserId.trim().isNotEmpty
              ? currentUserId.trim()
              : currentUserEmail.trim().toLowerCase(): {
            'id': currentUserId.trim(),
            'name': currentUserName.trim(),
            'email': currentUserEmail.trim().toLowerCase(),
            'role': currentRole.trim().toLowerCase(),
          },
          otherUserId.trim().isNotEmpty
              ? otherUserId.trim()
              : otherUserEmail.trim().toLowerCase(): {
            'id': otherUserId.trim(),
            'name': otherUserName.trim(),
            'email': otherUserEmail.trim().toLowerCase(),
            'role': otherRole.trim().toLowerCase(),
          },
        },
        'updatedAt': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      };
      transaction.set(ref, payload, SetOptions(merge: true));
    });
    return conversationId;
  }
  Future<void> sendMessage({
    required String conversationId,
    required String text,
    required String otherUserId,
    required String otherUserEmail,
  }) async {
    final cleanText = text.trim();
    if (conversationId.trim().isEmpty) {
      throw ArgumentError('La conversación no es válida.');
    }
    if (cleanText.isEmpty) return;
    final recipientKey = otherUserId.isNotEmpty ? otherUserId : otherUserEmail.toLowerCase();
    final senderKey = currentUserId.isNotEmpty ? currentUserId : currentUserEmail.toLowerCase();
    final batch = FirebaseFirestore.instance.batch();
    final messageRef = messagesRef(conversationId).doc();
    batch.set(messageRef, {
      'senderId': currentUserId,
      'senderKey': senderKey,
      'senderName': currentUserName,
      'senderEmail': currentUserEmail.toLowerCase(),
      'text': cleanText,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(conversationRef(conversationId), {
      'lastMessage': cleanText,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': currentUserId,
      'lastSenderName': currentUserName,
      'unreadBy': {recipientKey: true},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
    await NotificationService(gymId: gymId).createNotification(
      userId: otherUserId,
      userEmail: otherUserEmail,
      type: 'chat_message',
      title: 'Nuevo mensaje',
      message: '$currentUserName te ha enviado un mensaje.',
      sourceId: conversationId,
      metadata: {'senderId': currentUserId, 'senderName': currentUserName},
    );
  }
  Future<void> markRead(String conversationId) async {
    final key = currentUserId.isNotEmpty ? currentUserId : currentUserEmail.toLowerCase();
    await conversationRef(conversationId).set({
      'unreadBy': {key: false},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
  String otherParticipantName(Map<String, dynamic> data) {
    final participants = data['participants'];
    if (participants is Map) {
      for (final entry in participants.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final email = (value['email'] ?? '').toString().toLowerCase();
        final id = value['id']?.toString() ?? '';
        final isMe = (currentUserId.isNotEmpty && id == currentUserId) ||
            (currentUserEmail.isNotEmpty && email == currentUserEmail.toLowerCase());
        if (!isMe) return value['name']?.toString() ?? 'Usuario';
      }
    }
    return 'Usuario';
  }
  ChatParticipant otherParticipant(Map<String, dynamic> data) {
    final participants = data['participants'];
    if (participants is Map) {
      for (final entry in participants.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final email = (value['email'] ?? '').toString().toLowerCase();
        final id = value['id']?.toString() ?? '';
        final isMe = (currentUserId.isNotEmpty && id == currentUserId) ||
            (currentUserEmail.isNotEmpty && email == currentUserEmail.toLowerCase());
        if (!isMe) {
          return ChatParticipant(
            id: id,
            name: value['name']?.toString() ?? 'Usuario',
            email: email,
            role: value['role']?.toString() ?? 'user',
          );
        }
      }
    }
    return const ChatParticipant(id: '', name: 'Usuario', email: '', role: 'user');
  }
  bool isUnread(Map<String, dynamic> data) {
    final unreadBy = data['unreadBy'];
    final key = currentUserId.isNotEmpty ? currentUserId : currentUserEmail.toLowerCase();
    return unreadBy is Map && unreadBy[key] == true;
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
}

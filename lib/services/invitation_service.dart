import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class GymInvitation {
  final String id;
  final String gymId;
  final String email;
  final String name;
  final String role;
  final String trainerRole;
  final String status;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final Map<String, dynamic> raw;
  const GymInvitation({required this.id, required this.gymId, required this.email, required this.name, required this.role, required this.trainerRole, required this.status, required this.createdAt, required this.expiresAt, required this.acceptedAt, required this.raw});
  bool get isPending => status == 'pending' && !isExpired;
  bool get isAccepted => status == 'accepted';
  bool get isRevoked => status == 'revoked';
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isTrainerInvite => role == 'trainer' || role == 'owner';
  bool get isClientInvite => role == 'user';
  String get roleLabel { if (role == 'user') return 'Cliente'; if (trainerRole == 'gym_admin') return 'Admin gimnasio'; if (role == 'owner') return 'Propietario'; return 'Entrenador'; }
  String get statusLabel { if (isExpired && status == 'pending') return 'Caducada'; switch (status) { case 'accepted': return 'Aceptada'; case 'revoked': return 'Revocada'; case 'expired': return 'Caducada'; case 'pending': return 'Pendiente'; default: return status; } }
  factory GymInvitation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) { final data = doc.data() ?? <String, dynamic>{}; return GymInvitation(id: doc.id, gymId: data['gymId']?.toString() ?? '', email: (data['email'] ?? '').toString().trim().toLowerCase(), name: data['name']?.toString() ?? '', role: data['role']?.toString() ?? 'user', trainerRole: data['trainerRole']?.toString() ?? 'trainer', status: data['status']?.toString() ?? 'pending', createdAt: _date(data['createdAt']), expiresAt: _date(data['expiresAt']), acceptedAt: _date(data['acceptedAt']), raw: data); }
  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class InvitationStats {
  final int total; final int pending; final int accepted; final int revoked; final int expired;
  const InvitationStats({required this.total, required this.pending, required this.accepted, required this.revoked, required this.expired});
  factory InvitationStats.fromInvites(List<GymInvitation> invites) { var pending=0, accepted=0, revoked=0, expired=0; for (final invite in invites) { if (invite.isExpired && invite.status == 'pending' || invite.status == 'expired') { expired++; } else if (invite.status == 'pending') { pending++; } else if (invite.status == 'accepted') { accepted++; } else if (invite.status == 'revoked') { revoked++; } } return InvitationStats(total: invites.length, pending: pending, accepted: accepted, revoked: revoked, expired: expired); }
}

class InvitationService {
  final String gymId;
  const InvitationService({required this.gymId});
  FirebaseFunctions get functions => FirebaseFunctions.instanceFor(region: 'europe-west1');
  CollectionReference<Map<String, dynamic>> get invitesRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('invites');
  DocumentReference<Map<String, dynamic>> inviteRef(String inviteId) => invitesRef.doc(inviteId);
  String buildInviteLink(String inviteId) { final base = Uri.base; return Uri(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null, path: base.path, queryParameters: {'gymId': gymId, 'inviteId': inviteId}).toString(); }
  Stream<List<GymInvitation>> watchInvites() => invitesRef.orderBy('createdAt', descending: true).snapshots().map((snapshot) => snapshot.docs.map(GymInvitation.fromDoc).toList());
  Future<String> createInvite({required String name, required String email, required String role, String trainerRole = 'trainer', required String createdByUid, required String createdByName, required String createdByEmail}) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedRole = role.trim().toLowerCase();
    final normalizedTrainerRole = trainerRole.trim().toLowerCase();
    if (normalizedName.isEmpty || normalizedEmail.isEmpty) {
      throw ArgumentError('El nombre y el email son obligatorios.');
    }
    if (!const {'user', 'trainer', 'owner'}.contains(normalizedRole)) {
      throw ArgumentError('El rol de la invitación no es válido.');
    }
    final result = await functions.httpsCallable('createInviteSecure').call({
      'gymId': gymId,
      'name': normalizedName,
      'email': normalizedEmail,
      'role': normalizedRole,
      'trainerRole': normalizedTrainerRole,
    });
    final rawData = result.data;
    if (rawData is! Map) {
      throw StateError('El servidor devolvió una respuesta de invitación no válida.');
    }
    final data = Map<String, dynamic>.from(rawData);
    final id = data['inviteId']?.toString().trim() ?? '';
    if (id.isEmpty) throw StateError('El servidor no devolvió la invitación.');
    return buildInviteLink(id);
  }
  Future<GymInvitation?> loadInvite(String inviteId) async { if (inviteId.trim().isEmpty) return null; final snapshot = await inviteRef(inviteId).get(); return snapshot.exists ? GymInvitation.fromDoc(snapshot) : null; }
  Future<void> revokeInvite(String inviteId, {required String actorUid, required String actorName, required String actorEmail}) async { await functions.httpsCallable('revokeInviteSecure').call({'gymId': gymId, 'inviteId': inviteId}); }
  Future<void> markExpired(GymInvitation invite, {required String actorUid, required String actorName, required String actorEmail}) async { if (!invite.isExpired || invite.status != 'pending') return; await functions.httpsCallable('markInviteExpiredSecure').call({'gymId': gymId, 'inviteId': invite.id}); }
  Future<void> acceptInvite({required String inviteId, required String name}) async { await functions.httpsCallable('acceptInviteSecure').call({'gymId': gymId, 'inviteId': inviteId, 'name': name.trim()}); }
}

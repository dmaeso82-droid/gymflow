import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProvisionedMember {
  final String uid;
  final String email;
  final String? clientId;
  const ProvisionedMember({required this.uid, required this.email, this.clientId});
}

class MemberProvisioningService {
  final String gymId;
  const MemberProvisioningService({required this.gymId});

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<ProvisionedMember> createClient({
    required String name,
    required String email,
    required String goal,
  }) async {
    final result = await _functions.httpsCallable('provisionClientSecure').call({
      'gymId': gymId,
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'goal': goal.trim(),
    });
    final data = _responseData(result.data);
    final member = _memberFromData(data, fallbackEmail: email, requireClientId: true);
    await _sendPasswordReset(member.email);
    return member;
  }

  Future<ProvisionedMember> createTrainer({
    required String name,
    required String email,
    required String trainerRole,
  }) async {
    final result = await _functions.httpsCallable('provisionTrainerSecure').call({
      'gymId': gymId,
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'trainerRole': trainerRole,
    });
    final data = _responseData(result.data);
    final member = _memberFromData(data, fallbackEmail: email);
    await _sendPasswordReset(member.email);
    return member;
  }

  Map<String, dynamic> _responseData(dynamic rawData) {
    if (rawData is! Map) {
      throw StateError('El servidor devolvió una respuesta de alta no válida.');
    }
    return Map<String, dynamic>.from(rawData);
  }

  ProvisionedMember _memberFromData(
    Map<String, dynamic> data, {
    required String fallbackEmail,
    bool requireClientId = false,
  }) {
    final uid = data['uid']?.toString().trim() ?? '';
    final normalizedEmail = (data['email']?.toString() ?? fallbackEmail).trim().toLowerCase();
    final clientId = data['clientId']?.toString().trim();
    if (uid.isEmpty || normalizedEmail.isEmpty || (requireClientId && (clientId == null || clientId.isEmpty))) {
      throw StateError('El servidor devolvió un alta incompleta.');
    }
    return ProvisionedMember(
      uid: uid,
      email: normalizedEmail,
      clientId: clientId == null || clientId.isEmpty ? null : clientId,
    );
  }

  Future<void> _sendPasswordReset(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(
      email: email.trim().toLowerCase(),
    );
  }

  String messageForError(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'already-exists':
        case 'resource-exhausted':
        case 'failed-precondition':
        case 'permission-denied':
        case 'invalid-argument':
          return error.message ?? 'No se pudo completar el alta.';
      }
      return error.message ?? 'Error de servidor: ${error.code}';
    }
    if (error is FirebaseAuthException) {
      return 'La cuenta se creó, pero no se pudo enviar el email de acceso: ${error.code}';
    }
    return 'No se pudo completar el alta: $error';
  }
}

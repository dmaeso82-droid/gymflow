part of 'trainer_routine_service.dart';

mixin RoutineAuditMixin {
  Future<Map<String, String>> currentActor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'uid': '', 'name': 'Sistema', 'email': ''};
    var name = user.displayName ?? '';
    final email = (user.email ?? '').toLowerCase();
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final storedName = userDoc.data()?['name']?.toString() ?? '';
      if (storedName.trim().isNotEmpty) name = storedName.trim();
    } catch (_) {
      // La identidad de Firebase permite continuar sin bloquear la operación.
    }
    if (name.trim().isEmpty) name = email.isEmpty ? 'Entrenador' : email;
    return {'uid': user.uid, 'name': name, 'email': email};
  }

  Map<String, dynamic> auditCreateFields(Map<String, String> actor) => {
        'createdBy': actor['name'] ?? '',
        'createdByUid': actor['uid'] ?? '',
        'updatedBy': actor['name'] ?? '',
        'updatedByUid': actor['uid'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> auditUpdateFields(Map<String, String> actor) => {
        'updatedBy': actor['name'] ?? '',
        'updatedByUid': actor['uid'] ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> activityFields({
    required String type,
    required String target,
    required Map<String, String> actor,
    String? targetId,
    String? targetEmail,
    Map<String, dynamic>? metadata,
  }) => {
        'type': type,
        'target': target,
        'targetId': targetId ?? '',
        'targetEmail': (targetEmail ?? '').toLowerCase(),
        'user': actor['name'] ?? '',
        'userUid': actor['uid'] ?? '',
        'userEmail': actor['email'] ?? '',
        'metadata': metadata ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      };
}

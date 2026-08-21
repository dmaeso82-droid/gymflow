import 'package:cloud_functions/cloud_functions.dart';

class SecureDeletionResult {
  final int deletedRelatedDocs;
  final bool authDeleted;
  const SecureDeletionResult({required this.deletedRelatedDocs, required this.authDeleted});
}

class SecureDeletionService {
  final String gymId;
  const SecureDeletionService({required this.gymId});

  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<SecureDeletionResult> deleteClient(String clientId) async {
    final result = await _functions.httpsCallable('deleteClientSecure').call({
      'gymId': gymId,
      'clientId': clientId,
    });
    return _result(result.data);
  }

  Future<SecureDeletionResult> deleteTrainer(String trainerUid) async {
    final result = await _functions.httpsCallable('deleteTrainerSecure').call({
      'gymId': gymId,
      'trainerUid': trainerUid,
    });
    return _result(result.data);
  }

  SecureDeletionResult _result(dynamic raw) {
    final data = Map<String, dynamic>.from(raw as Map);
    return SecureDeletionResult(
      deletedRelatedDocs: (data['deletedRelatedDocs'] as num?)?.toInt() ?? 0,
      authDeleted: data['authDeleted'] == true,
    );
  }

  String messageForError(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.message ?? 'No se pudo completar el borrado (${error.code}).';
    }
    return 'No se pudo completar el borrado: $error';
  }
}

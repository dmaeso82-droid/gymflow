import 'package:cloud_functions/cloud_functions.dart';

class SecureUpdateService {
  final String gymId;
  const SecureUpdateService({required this.gymId});
  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<void> updateClient({required String clientId, required String name, required String email, required String goal}) async {
    await _functions.httpsCallable('updateClientSecure').call({'gymId': gymId, 'clientId': clientId, 'name': name.trim(), 'email': email.trim().toLowerCase(), 'goal': goal.trim()});
  }
  Future<void> updateTrainer({required String trainerUid, required String name, required String trainerRole}) async {
    await _functions.httpsCallable('updateTrainerSecure').call({'gymId': gymId, 'trainerUid': trainerUid, 'name': name.trim(), 'trainerRole': trainerRole});
  }
  Future<bool> toggleTrainerStatus({required String trainerUid, required bool active}) async {
    final result = await _functions.httpsCallable('toggleTrainerStatusSecure').call({'gymId': gymId, 'trainerUid': trainerUid, 'active': active});
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['active'] == true;
  }
  String messageForError(Object error) => error is FirebaseFunctionsException ? (error.message ?? 'No se pudo guardar el cambio (${error.code}).') : 'No se pudo guardar el cambio: $error';
}

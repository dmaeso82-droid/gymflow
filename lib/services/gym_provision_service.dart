import 'package:cloud_functions/cloud_functions.dart';
class GymProvisionService {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  Future<void> provision({required String ownerName,required String gymName,required String phone,required String address,required String email}) async {
    await _functions.httpsCallable('provisionFreeGym').call({
      'ownerName': ownerName,
      'gymName': gymName,
      'phone': phone,
      'address': address,
      'email': email,
    });
  }
}

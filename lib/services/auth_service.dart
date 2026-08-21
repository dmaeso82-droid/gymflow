import 'package:firebase_auth/firebase_auth.dart';
class AuthService {
  Future<void> login(String email,String password) {
    return FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim().toLowerCase(), password: password.trim());
  }
  Future<void> sendReset(String email){
    return FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }
}

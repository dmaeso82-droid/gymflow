
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  bool registerMode = false;
  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showSnack('Introduce email y contraseña.');
      return;
    }

    if (registerMode && name.isEmpty) {
      showSnack('Introduce tu nombre.');
      return;
    }

    setState(() => loading = true);

    try {
      if (registerMode) {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final uid = credential.user!.uid;
        final db = FirebaseFirestore.instance;

        await db.collection('gyms').doc(defaultGymId).set({
          'name': defaultGymName,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await db.collection('users').doc(uid).set({
          'name': name,
          'email': email,
          'role': 'trainer',
          'trainerRole': 'gym_admin',
          'gymId': defaultGymId,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await db.collection('gyms').doc(defaultGymId).collection('members').doc(uid).set({
          'name': name,
          'email': email,
          'role': 'trainer',
          'trainerRole': 'gym_admin',
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await db.collection('gyms').doc(defaultGymId).collection('trainers').doc(uid).set({
          'name': name,
          'email': email,
          'role': 'trainer',
          'trainerRole': 'gym_admin',
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      showSnack(authMessage(e.code));
    } catch (e) {
      showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      showSnack('Introduce el email para recuperar la contraseña.');
      return;
    }

    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      showSnack('Te hemos enviado un correo para restablecer la contraseña.');
    } on FirebaseAuthException catch (e) {
      showSnack(authMessage(e.code));
    } catch (e) {
      showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String authMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Ese email ya está registrado.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'invalid-email':
        return 'Email no válido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email o contraseña incorrectos.';
      default:
        return 'Error de autenticación: $code';
    }
  }

  void showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.fitness_center, size: 52, color: Colors.greenAccent),
                    SizedBox(height: 12),
                    Text(
                      'GymFlow',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 8),
                    Text(
                      registerMode ? 'Crear cuenta admin de $defaultGymName' : 'Iniciar sesión',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 24),
                    if (registerMode) ...[
                      AppTextField(controller: nameController, label: 'Nombre del administrador'),
                      SizedBox(height: 12),
                      Text(
                        'Esta cuenta será admin del gimnasio. Los entrenadores se crean después desde el panel de Entrenadores.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      SizedBox(height: 12),
                    ],
                    AppTextField(
                      controller: emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 12),
                    AppTextField(
                      controller: passwordController,
                      label: 'Contraseña',
                      obscureText: true,
                    ),
                    SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: loading ? null : submit,
                      icon: loading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.login),
                      label: Text(registerMode ? 'Crear admin de $defaultGymName' : 'Entrar'),
                    ),
                    TextButton(
                      onPressed: loading ? null : () => setState(() => registerMode = !registerMode),
                      child: Text(registerMode ? 'Ya tengo cuenta' : 'Registrarme como admin de gimnasio'),
                    ),
                    if (!registerMode)
                      TextButton(
                        onPressed: loading ? null : resetPassword,
                        child: Text('¿Has olvidado la contraseña?'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}




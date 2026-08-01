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
  String selectedRole = 'trainer';

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

        await db.collection('users').doc(uid).set({
          'name': name,
          'email': email,
          'role': selectedRole,
          'gymId': demoGymId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await db.collection('gyms').doc(demoGymId).set({
          'name': 'GymFlow Demo',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await db
            .collection('gyms')
            .doc(demoGymId)
            .collection('members')
            .doc(uid)
            .set({
          'name': name,
          'email': email,
          'role': selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
        });
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
                    const Icon(Icons.fitness_center, size: 52, color: Colors.greenAccent),
                    const SizedBox(height: 12),
                    const Text(
                      'GymFlow',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      registerMode ? 'Crear cuenta' : 'Iniciar sesión',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    if (registerMode) ...[
                      AppTextField(controller: nameController, label: 'Nombre'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        dropdownColor: const Color(0xFF0F172A),
                        decoration: const InputDecoration(
                          labelText: 'Rol',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'trainer', child: Text('Entrenador')),
                          DropdownMenuItem(value: 'user', child: Text('Usuario')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => selectedRole = value);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    AppTextField(
                      controller: emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: passwordController,
                      label: 'Contraseña',
                      obscureText: true,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: loading ? null : submit,
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(registerMode ? 'Crear cuenta' : 'Entrar'),
                    ),
                    TextButton(
                      onPressed: loading ? null : () => setState(() => registerMode = !registerMode),
                      child: Text(registerMode ? 'Ya tengo cuenta' : 'Crear cuenta nueva'),
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

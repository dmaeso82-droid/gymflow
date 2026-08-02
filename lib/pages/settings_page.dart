
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/section_title.dart';

class SettingsPage extends StatefulWidget {
  final String userEmail;

  const SettingsPage({super.key, required this.userEmail});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String authMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'La nueva contraseña es demasiado débil.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'La contraseña actual no es correcta.';
      case 'requires-recent-login':
        return 'Por seguridad, vuelve a iniciar sesión y prueba otra vez.';
      default:
        return 'Error de autenticación: $code';
    }
  }

  Future<void> changePassword() async {
    final currentPassword = currentPasswordController.text.trim();
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? widget.userEmail;

    if (user == null || email.isEmpty) {
      showSnack('No se ha encontrado el usuario actual.');
      return;
    }

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      showSnack('Rellena todos los campos.');
      return;
    }

    if (newPassword != confirmPassword) {
      showSnack('La nueva contraseña y la confirmación no coinciden.');
      return;
    }

    if (newPassword.length < 6) {
      showSnack('La nueva contraseña debe tener al menos 6 caracteres.');
      return;
    }

    setState(() => loading = true);
    try {
      final credential = EmailAuthProvider.credential(email: email, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      currentPasswordController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();
      showSnack('Contraseña actualizada.');
    } on FirebaseAuthException catch (e) {
      showSnack(authMessage(e.code));
    } catch (e) {
      showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> sendPasswordReset() async {
    final email = FirebaseAuth.instance.currentUser?.email ?? widget.userEmail;
    if (email.isEmpty) {
      showSnack('No se ha encontrado el email del usuario.');
      return;
    }

    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.toLowerCase());
      showSnack('Te hemos enviado un correo para restablecer la contraseña.');
    } on FirebaseAuthException catch (e) {
      showSnack(authMessage(e.code));
    } catch (e) {
      showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(icon: Icons.lock, title: 'Cambiar contraseña'),
                  const SizedBox(height: 12),
                  Text('Cuenta: ${widget.userEmail}', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: currentPasswordController,
                    label: 'Contraseña actual',
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: newPasswordController,
                    label: 'Nueva contraseña',
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: confirmPasswordController,
                    label: 'Confirmar nueva contraseña',
                    obscureText: true,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: loading ? null : changePassword,
                      icon: const Icon(Icons.save),
                      label: const Text('Actualizar contraseña'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : sendPasswordReset,
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('Enviar email para restablecer contraseña'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                  onPressed: loading ? null : signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

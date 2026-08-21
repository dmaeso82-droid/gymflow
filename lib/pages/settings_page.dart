import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/section_title.dart';
import 'invitations_page.dart';
import 'subscription_page.dart';

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
  final gymNameController = TextEditingController();
  final gymPhoneController = TextEditingController();
  final gymAddressController = TextEditingController();
  final gymLogoController = TextEditingController();
  final gymPrimaryColorController = TextEditingController();
  bool loading = false;
  bool gymFieldsLoaded = false;

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    gymNameController.dispose();
    gymPhoneController.dispose();
    gymAddressController.dispose();
    gymLogoController.dispose();
    gymPrimaryColorController.dispose();
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

  String themeLabel(GymFlowThemePreference value) {
    switch (value) {
      case GymFlowThemePreference.system:
        return 'Automático';
      case GymFlowThemePreference.light:
        return 'Claro';
      case GymFlowThemePreference.dark:
        return 'Oscuro';
    }
  }

  IconData themeIcon(GymFlowThemePreference value) {
    switch (value) {
      case GymFlowThemePreference.system:
        return Icons.brightness_auto;
      case GymFlowThemePreference.light:
        return Icons.light_mode;
      case GymFlowThemePreference.dark:
        return Icons.dark_mode;
    }
  }

  bool canManageGym(Map<String, dynamic>? userData) {
    final role = userData?['role']?.toString() ?? roleUser;
    final trainerRole = userData?['trainerRole']?.toString() ?? trainerRoleTrainer;
    return role == roleOwner || trainerRole == trainerRoleGymAdmin;
  }

  String userGymId(Map<String, dynamic>? userData) {
    return userData?['gymId']?.toString() ?? defaultGymId;
  }

  void fillGymFields(Map<String, dynamic>? gymData) {
    if (gymFieldsLoaded || gymData == null) return;
    gymNameController.text = gymData['name']?.toString() ?? defaultGymName;
    gymPhoneController.text = gymData['phone']?.toString() ?? '';
    gymAddressController.text = gymData['address']?.toString() ?? '';
    gymLogoController.text = gymData['logoUrl']?.toString() ?? '';
    gymPrimaryColorController.text = gymData['primaryColor']?.toString() ?? '';
    gymFieldsLoaded = true;
  }

  Future<void> saveGymSettings(String gymId) async {
    final name = gymNameController.text.trim();
    if (name.isEmpty) {
      showSnack('Introduce el nombre del gimnasio.');
      return;
    }
    setState(() => loading = true);
    try {
      await FirebaseFirestore.instance.collection('gyms').doc(gymId).set({
        'name': name,
        'phone': gymPhoneController.text.trim(),
        'address': gymAddressController.text.trim(),
        'logoUrl': gymLogoController.text.trim(),
        'primaryColor': gymPrimaryColorController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      showSnack('Gimnasio actualizado.');
    } catch (e) {
      showSnack('Error guardando el gimnasio: $e');
    } finally {
      if (mounted) setState(() => loading = false);
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

  Widget appearanceCard(BuildContext context, Color textColor, Color mutedColor) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(icon: Icons.palette, title: 'Apariencia'),
          const SizedBox(height: 12),
          Text('Elige los colores de GymFlow. El modo claro usa blanco y azul celeste; el modo oscuro mantiene fondo nocturno con acento celeste.', style: TextStyle(color: mutedColor)),
          const SizedBox(height: 14),
          ValueListenableBuilder<GymFlowThemePreference>(
            valueListenable: ThemeController.preference,
            builder: (context, currentTheme, _) {
              return Column(
                children: GymFlowThemePreference.values.map((option) {
                  final selected = option == currentTheme;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => ThemeController.setPreference(option),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12) : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor),
                        ),
                        child: Row(children: [
                          Icon(themeIcon(option), color: selected ? Theme.of(context).colorScheme.primary : mutedColor),
                          const SizedBox(width: 10),
                          Expanded(child: Text(themeLabel(option), style: TextStyle(color: textColor, fontWeight: FontWeight.w900))),
                          if (selected) Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                        ]),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget gymSettingsCard({required String gymId, required bool canEdit, required Map<String, dynamic>? gymData, required Color mutedColor}) {
    fillGymFields(gymData);
    final plan = gymData?['plan']?.toString() ?? defaultSubscriptionPlan;
    final status = gymData?['subscriptionStatus']?.toString() ?? defaultSubscriptionStatus;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle(icon: Icons.storefront, title: 'Gimnasio SaaS'),
        const SizedBox(height: 12),
        Text('Tenant: $gymId · Plan: $plan · Estado: $status', style: TextStyle(color: mutedColor)),
        const SizedBox(height: 12),
        AppTextField(controller: gymNameController, label: 'Nombre del gimnasio'),
        const SizedBox(height: 12),
        AppTextField(controller: gymPhoneController, label: 'Teléfono', keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        AppTextField(controller: gymAddressController, label: 'Dirección'),
        const SizedBox(height: 12),
        AppTextField(controller: gymLogoController, label: 'URL del logo'),
        const SizedBox(height: 12),
        AppTextField(controller: gymPrimaryColorController, label: 'Color principal', hint: '#4CAF50'),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: loading || !canEdit ? null : () => saveGymSettings(gymId), icon: const Icon(Icons.save), label: Text(canEdit ? 'Guardar datos del gimnasio' : 'Solo el propietario o admin puede editar'))),
      ]),
    );
  }

  Widget subscriptionCard({required String gymId, required bool canEdit, required Color mutedColor}) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle(icon: Icons.workspace_premium, title: 'Plan y límites'),
        const SizedBox(height: 12),
        Text('Gestiona el plan piloto, límites de clientes y entrenadores, funciones activas y estado de suscripción.', style: TextStyle(color: mutedColor)),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: canEdit ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionPage(gymId: gymId))) : null, icon: const Icon(Icons.tune), label: Text(canEdit ? 'Abrir plan SaaS' : 'Solo el propietario o admin puede gestionar el plan'))),
      ]),
    );
  }

  Widget invitationsCard({required String gymId, required bool canEdit, required Color mutedColor}) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle(icon: Icons.link, title: 'Invitaciones'),
        const SizedBox(height: 12),
        Text('Crea enlaces para que entrenadores y clientes se registren solos en este gimnasio.', style: TextStyle(color: mutedColor)),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: canEdit ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvitationsPage(gymId: gymId))) : null, icon: const Icon(Icons.person_add_alt_1), label: Text(canEdit ? 'Crear invitaciones' : 'Solo el propietario o admin puede invitar'))),
      ]),
    );
  }

  Widget passwordCard(Color mutedColor) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle(icon: Icons.lock, title: 'Cambiar contraseña'),
        const SizedBox(height: 12),
        Text('Cuenta: ${widget.userEmail}', style: TextStyle(color: mutedColor)),
        const SizedBox(height: 12),
        AppTextField(controller: currentPasswordController, label: 'Contraseña actual', obscureText: true),
        const SizedBox(height: 12),
        AppTextField(controller: newPasswordController, label: 'Nueva contraseña', obscureText: true),
        const SizedBox(height: 12),
        AppTextField(controller: confirmPasswordController, label: 'Confirmar nueva contraseña', obscureText: true),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: loading ? null : changePassword, icon: const Icon(Icons.save), label: const Text('Actualizar contraseña'))),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: loading ? null : sendPasswordReset, icon: const Icon(Icons.email_outlined), label: const Text('Enviar email para restablecer contraseña'))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = textColor.withValues(alpha: 0.70);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: uid.isEmpty ? null : FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, userSnapshot) {
            final userData = userSnapshot.data?.data();
            final gymId = userGymId(userData);
            final canEdit = canManageGym(userData);
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('gyms').doc(gymId).snapshots(),
              builder: (context, gymSnapshot) {
                final gymData = gymSnapshot.data?.data();
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    appearanceCard(context, textColor, mutedColor),
                    const SizedBox(height: 16),
                    gymSettingsCard(gymId: gymId, canEdit: canEdit, gymData: gymData, mutedColor: mutedColor),
                    const SizedBox(height: 16),
                    subscriptionCard(gymId: gymId, canEdit: canEdit, mutedColor: mutedColor),
                    const SizedBox(height: 16),
                    invitationsCard(gymId: gymId, canEdit: canEdit, mutedColor: mutedColor),
                    const SizedBox(height: 16),
                    passwordCard(mutedColor),
                    const SizedBox(height: 16),
                    AppCard(child: SizedBox(width: double.infinity, child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent), onPressed: loading ? null : signOut, icon: const Icon(Icons.logout), label: const Text('Cerrar sesión')))),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

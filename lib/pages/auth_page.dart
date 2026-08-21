import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/invitation_service.dart';
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
  final ownerNameController = TextEditingController();
  final gymNameController = TextEditingController();
  final gymPhoneController = TextEditingController();
  final gymAddressController = TextEditingController();
  bool loading = false;
  bool registerGymMode = false;
  late final String inviteGymId;
  late final String inviteId;

  bool get inviteMode => inviteGymId.isNotEmpty && inviteId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    inviteGymId = Uri.base.queryParameters['gymId'] ?? '';
    inviteId = Uri.base.queryParameters['inviteId'] ?? '';
    registerGymMode = inviteMode;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    ownerNameController.dispose();
    gymNameController.dispose();
    gymPhoneController.dispose();
    gymAddressController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      showSnack('Introduce email y contraseña.');
      return;
    }
    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      showSnack(authMessage(e.code));
    } catch (e) {
      showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> acceptInvitation() async {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();
    final name = ownerNameController.text.trim();
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      showSnack('Introduce nombre, email y contraseña.');
      return;
    }
    if (password.length < 6) {
      showSnack('La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    setState(() => loading = true);
    try {
      final inviteService = InvitationService(gymId: inviteGymId);
      final invite = await inviteService.loadInvite(inviteId);
      if (invite == null || !invite.isPending || invite.isExpired) {
        showSnack('La invitación no existe, ya se ha usado o ha caducado.');
        return;
      }
      if (invite.email != email) {
        showSnack('El email no coincide con la invitación.');
        return;
      }
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user == null) throw StateError('No se ha podido crear la cuenta.');
      await user.updateDisplayName(name);
      final db = FirebaseFirestore.instance;
      final gymRef = db.collection('gyms').doc(inviteGymId);
      final now = FieldValue.serverTimestamp();
      final batch = db.batch();
      batch.set(db.collection('users').doc(user.uid), {
        'uid': user.uid,
        'name': name,
        'email': email,
        'role': invite.role,
        'trainerRole': invite.trainerRole,
        'gymId': inviteGymId,
        'active': true,
        'acceptedInviteId': invite.id,
        'createdAt': now,
        'updatedAt': now,
      });
      final memberData = {
        'authUid': user.uid,
        'name': name,
        'email': email,
        'role': invite.role,
        'trainerRole': invite.trainerRole,
        'active': true,
        'inviteId': invite.id,
        'createdAt': now,
        'updatedAt': now,
      };
      batch.set(gymRef.collection('members').doc(user.uid), memberData);
      if (invite.isTrainerInvite) {
        batch.set(gymRef.collection('trainers').doc(user.uid), memberData);
      } else {
        batch.set(gymRef.collection('clients').doc(user.uid), {
          'authUid': user.uid,
          'name': name,
          'email': email,
          'goal': 'Objetivo pendiente',
          'level': 'Nuevo',
          'accountStatus': 'active',
          'inviteId': invite.id,
          'createdAt': now,
          'updatedAt': now,
        });
      }
      batch.set(gymRef.collection('invites').doc(invite.id), {
        'status': 'accepted',
        'acceptedByUid': user.uid,
        'acceptedAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));
      batch.set(gymRef.collection('audit_logs').doc(), {
        'type': 'invite_accepted',
        'actorUid': user.uid,
        'actorName': name,
        'actorEmail': email,
        'target': invite.id,
        'metadata': {'role': invite.role, 'trainerRole': invite.trainerRole},
        'createdAt': now,
      });
      await batch.commit();
    } on FirebaseAuthException catch (e) {
      showSnack(authMessage(e.code));
    } catch (e) {
      showSnack('Error aceptando la invitación: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> registerGymOwner() async {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();
    final ownerName = ownerNameController.text.trim();
    final gymName = gymNameController.text.trim();
    final gymPhone = gymPhoneController.text.trim();
    final gymAddress = gymAddressController.text.trim();
    if (email.isEmpty || password.isEmpty || ownerName.isEmpty || gymName.isEmpty) {
      showSnack('Introduce nombre, gimnasio, email y contraseña.');
      return;
    }
    if (password.length < 6) {
      showSnack('La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    setState(() => loading = true);
    User? createdUser;
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      createdUser = credential.user;
      if (createdUser == null) throw StateError('No se ha podido crear el usuario.');
      await createdUser.updateDisplayName(ownerName);
      await createdUser.getIdToken(true);

      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('provisionFreeGym');
      await callable.call(<String, dynamic>{
        'ownerName': ownerName,
        'gymName': gymName,
        'phone': gymPhone,
        'address': gymAddress,
        'email': email,
      });
      await createdUser.getIdToken(true);
      if (mounted) {
        showSnack('Gimnasio creado con el plan Free.');
      }
    } on FirebaseFunctionsException catch (e) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }
      showSnack('No se pudo crear el gimnasio: ${e.message ?? e.code}');
    } on FirebaseAuthException catch (e) {
      showSnack(authMessage(e.code));
    } catch (e) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }
      showSnack('Error creando el gimnasio: $e');
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
        return 'Ese email ya está registrado. Si ya tienes cuenta, inicia sesión normalmente.';
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final titleText = inviteMode ? 'Aceptar invitación' : registerGymMode ? 'Crea tu gimnasio en modo piloto' : 'Iniciar sesión';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.fitness_center, size: 52, color: Colors.greenAccent),
                    const SizedBox(height: 12),
                    const Text('GymFlow', textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(titleText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    if (!inviteMode)
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(value: false, icon: Icon(Icons.login), label: Text('Entrar')),
                          ButtonSegment<bool>(value: true, icon: Icon(Icons.storefront), label: Text('Nuevo gimnasio')),
                        ],
                        selected: {registerGymMode},
                        onSelectionChanged: loading ? null : (values) => setState(() => registerGymMode = values.first),
                      ),
                    const SizedBox(height: 20),
                    if (inviteMode) ...[
                      AppTextField(controller: ownerNameController, label: 'Tu nombre'),
                      const SizedBox(height: 12),
                    ] else if (registerGymMode) ...[
                      AppTextField(controller: ownerNameController, label: 'Tu nombre'),
                      const SizedBox(height: 12),
                      AppTextField(controller: gymNameController, label: 'Nombre del gimnasio'),
                      const SizedBox(height: 12),
                      AppTextField(controller: gymPhoneController, label: 'Teléfono del gimnasio', keyboardType: TextInputType.phone),
                      const SizedBox(height: 12),
                      AppTextField(controller: gymAddressController, label: 'Dirección del gimnasio'),
                      const SizedBox(height: 12),
                      AppCard(
                        child: Row(
                          children: const [
                            Icon(Icons.card_giftcard, color: Colors.greenAccent),
                            SizedBox(width: 10),
                            Expanded(child: Text('Plan Free incluido: 1 cliente y 2 entrenadores sin pago (incluido el propietario).')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      const Text('Accede con una cuenta ya creada por el gimnasio o registra un gimnasio piloto desde esta pantalla.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 12),
                    ],
                    AppTextField(controller: emailController, label: 'Email', keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    AppTextField(controller: passwordController, label: 'Contraseña', obscureText: true),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: loading ? null : inviteMode ? acceptInvitation : (registerGymMode ? registerGymOwner : submit),
                      icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(inviteMode ? Icons.how_to_reg : registerGymMode ? Icons.storefront : Icons.login),
                      label: Text(inviteMode ? 'Aceptar invitación' : registerGymMode ? 'Crear gimnasio piloto' : 'Entrar'),
                    ),
                    if (!registerGymMode && !inviteMode) TextButton(onPressed: loading ? null : resetPassword, child: const Text('¿Has olvidado la contraseña?')),
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

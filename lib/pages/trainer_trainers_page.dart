import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../firebase_options.dart';
import '../services/subscription_service.dart';
import '../services/member_provisioning_service.dart';
import '../services/secure_deletion_service.dart';
import '../services/secure_update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/profile_avatar.dart';

class TrainerTrainersPage extends StatefulWidget {
  final String gymId;
  final String trainerRole;
  const TrainerTrainersPage({super.key, required this.gymId, required this.trainerRole});

  @override
  State<TrainerTrainersPage> createState() => _TrainerTrainersPageState();
}

class _TrainerTrainersPageState extends State<TrainerTrainersPage> {
  CollectionReference<Map<String, dynamic>> get trainersRef => FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('trainers');
  DocumentReference<Map<String, dynamic>> get gymRef => FirebaseFirestore.instance.collection('gyms').doc(widget.gymId);
  DocumentReference<Map<String, dynamic>> get subscriptionRef => FirebaseFirestore.instance.collection('subscriptions').doc(widget.gymId);
  SubscriptionService get subscriptionService => SubscriptionService(gymId: widget.gymId);
  bool get canManage => widget.trainerRole == trainerRoleGymAdmin;

  void showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String temporaryPassword() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return 'GymFlow_${timestamp.substring(timestamp.length - 6)}!';
  }

  String roleLabel(String role) {
    switch (role) {
      case trainerRoleGymAdmin:
        return 'Admin gimnasio';
      case roleOwner:
        return 'Propietario';
      case trainerRoleTrainer:
      default:
        return 'Entrenador';
    }
  }

  int trainerLimitForPlan(String plan) {
    switch (plan) {
      case 'enterprise':
        return 999999;
      case 'pro':
        return 10;
      case 'starter':
      default:
        return 1;
    }
  }

  Future<UserCredential> createAuthTrainerAccount({required String name, required String email, required String password}) async {
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(name: 'trainerCreator_${DateTime.now().microsecondsSinceEpoch}', options: DefaultFirebaseOptions.currentPlatform);
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(email: email, password: password);
      await credential.user?.updateDisplayName(name);
      await secondaryAuth.signOut();
      return credential;
    } finally {
      await secondaryApp?.delete();
    }
  }

  Future<bool> canCreateAnotherTrainer() async {
    final subscriptionPlan = await subscriptionService.loadPlan();
    if (!subscriptionPlan.isActive) {
      showSnack('La suscripción del gimnasio no está activa. No se pueden crear entrenadores.');
      return false;
    }
    final subscription = await subscriptionRef.get();
    final plan = subscription.data()?['plan']?.toString() ?? defaultSubscriptionPlan;
    final limit = trainerLimitForPlan(plan);
    if (limit >= 999999) return true;
    final current = await trainersRef.where('active', isEqualTo: true).get();
    if (current.docs.length >= limit) {
      showSnack('El plan $plan permite hasta $limit entrenador${limit == 1 ? '' : 'es'} activo${limit == 1 ? '' : 's'}.');
      return false;
    }
    return true;
  }

  Future<void> createTrainer() async {
    if (!canManage) {
      showSnack('Solo un admin de gimnasio puede crear entrenadores.');
      return;
    }
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    var selectedRole = trainerRoleTrainer;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.gymSurface,
              title: Text('Nuevo entrenador'),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AppTextField(controller: nameController, label: 'Nombre'),
                  SizedBox(height: 12),
                  AppTextField(controller: emailController, label: 'Email', keyboardType: TextInputType.emailAddress),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    dropdownColor: context.gymSurface,
                    decoration: InputDecoration(labelText: 'Rol', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                    items: const [
                      DropdownMenuItem(value: trainerRoleTrainer, child: Text('Entrenador')),
                      DropdownMenuItem(value: trainerRoleGymAdmin, child: Text('Admin gimnasio')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedRole = value);
                    },
                  ),
                  SizedBox(height: 12),
                  Text('Se creará una cuenta de acceso dentro de este gimnasio y se enviará un email para establecer la contraseña.', style: TextStyle(color: context.gymMutedText)),
                ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancelar')),
                FilledButton.icon(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final email = emailController.text.trim().toLowerCase();
                    if (name.isEmpty || email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Introduce nombre y email.')));
                      return;
                    }
                    Navigator.pop(dialogContext, {'name': name, 'email': email, 'trainerRole': selectedRole});
                  },
                  icon: Icon(Icons.person_add),
                  label: Text('Crear entrenador'),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
    emailController.dispose();
    if (result == null) return;
    final service = MemberProvisioningService(gymId: widget.gymId);
    try {
      await service.createTrainer(
        name: result['name']!,
        email: result['email']!,
        trainerRole: result['trainerRole']!,
      );
      if (!mounted) return;
      showSnack('Entrenador creado. Se ha enviado el email para establecer contraseña.');
    } catch (error) {
      if (!mounted) return;
      showSnack(service.messageForError(error));
    }
  }
  Future<void> editTrainer(String uid, Map<String, dynamic> data) async {
    if (!canManage) {
      showSnack('Solo un admin de gimnasio puede editar entrenadores.');
      return;
    }
    final nameController = TextEditingController(text: data['name']?.toString() ?? '');
    var selectedRole = data['trainerRole']?.toString() ?? trainerRoleTrainer;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.gymSurface,
              title: Text('Editar entrenador'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                AppTextField(controller: nameController, label: 'Nombre'),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  dropdownColor: context.gymSurface,
                  decoration: InputDecoration(labelText: 'Rol', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                  items: const [
                    DropdownMenuItem(value: trainerRoleTrainer, child: Text('Entrenador')),
                    DropdownMenuItem(value: trainerRoleGymAdmin, child: Text('Admin gimnasio')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedRole = value);
                  },
                ),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancelar')),
                FilledButton.icon(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(dialogContext, {'name': name, 'trainerRole': selectedRole});
                  },
                  icon: Icon(Icons.save),
                  label: Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
    if (result == null) return;
    final service = SecureUpdateService(gymId: widget.gymId);
    try {
      await service.updateTrainer(trainerUid: uid, name: result['name']!, trainerRole: result['trainerRole']!);
      if (!mounted) return;
      showSnack('Entrenador actualizado.');
    } catch (error) {
      if (!mounted) return;
      showSnack(service.messageForError(error));
    }
  }
  Future<void> toggleActive(String uid, Map<String, dynamic> data) async {
    if (!canManage) { showSnack('Solo un admin de gimnasio puede activar o desactivar entrenadores.'); return; }
    final service = SecureUpdateService(gymId: widget.gymId);
    final nextActive = data['active'] == false;
    try {
      final active = await service.toggleTrainerStatus(trainerUid: uid, active: nextActive);
      if (!mounted) return;
      showSnack(active ? 'Entrenador activado.' : 'Entrenador desactivado.');
    } catch (error) {
      if (!mounted) return;
      showSnack(service.messageForError(error));
    }
  }
  Future<void> deleteTrainer(String uid, Map<String, dynamic> data) async {
    if (!canManage) return;
    final name = data['name']?.toString() ?? 'este entrenador';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.gymSurface,
        title: const Text('Eliminar entrenador'),
        content: Text('¿Seguro que quieres eliminar a $name? Se eliminarán su cuenta y sus datos asociados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final service = SecureDeletionService(gymId: widget.gymId);
    try {
      final result = await service.deleteTrainer(uid);
      if (!mounted) return;
      showSnack('Entrenador eliminado. Se limpiaron ${result.deletedRelatedDocs} documentos asociados.');
    } catch (error) {
      if (!mounted) return;
      showSnack(service.messageForError(error));
    }
  }

  Future<void> resendPasswordEmail(String email) async {
    if (!canManage) {
      showSnack('Solo un admin de gimnasio puede reenviar accesos.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.toLowerCase());
      showSnack('Email de acceso enviado.');
    } on FirebaseAuthException catch (e) {
      showSnack('No se pudo enviar el email: ${e.code}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    final pagePadding = isCompact ? 12.0 : 16.0;
    final avatarSize = isCompact ? 42.0 : 56.0;
    return Scaffold(
      appBar: AppBar(title: Text('Entrenadores')),
      floatingActionButton: canManage
          ? isCompact
              ? FloatingActionButton(onPressed: createTrainer, child: Icon(Icons.person_add))
              : FloatingActionButton.extended(onPressed: createTrainer, icon: Icon(Icons.person_add), label: Text('Nuevo entrenador'))
          : null,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: gymRef.snapshots(),
          builder: (context, gymSnapshot) {
            final gymName = gymSnapshot.data?.data()?['name']?.toString() ?? defaultGymName;
            final plan = gymSnapshot.data?.data()?['plan']?.toString() ?? defaultSubscriptionPlan;
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: trainersRef.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
                final trainers = snapshot.data?.docs ?? [];
                return ListView(padding: EdgeInsets.all(pagePadding), children: [
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Icon(Icons.groups, color: context.gymPrimary, size: 20), SizedBox(width: 8), Text('Equipo de entrenadores', style: TextStyle(fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.w900))]),
                      SizedBox(height: isCompact ? 8 : 12),
                      Text(canManage ? 'Gestiona entrenadores de $gymName. Plan actual: $plan.' : 'Puedes ver el equipo de $gymName. Solo un admin puede crear o editar entrenadores.', style: TextStyle(color: context.gymMutedText, fontSize: isCompact ? 13 : 14)),
                    ]),
                  ),
                  SizedBox(height: isCompact ? 10 : 16),
                  if (trainers.isEmpty)
                    AppCard(child: Text('Todavía no hay entrenadores registrados en este gimnasio.', style: TextStyle(color: context.gymMutedText)))
                  else
                    ...trainers.map((doc) {
                      final data = doc.data();
                      final name = data['name']?.toString() ?? 'Entrenador';
                      final email = data['email']?.toString() ?? '';
                      final trainerRole = data['trainerRole']?.toString() ?? trainerRoleTrainer;
                      final active = data['active'] != false;
                      return AppCard(
                        margin: EdgeInsets.only(bottom: isCompact ? 8 : 12),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          ProfileAvatar(name: name, size: avatarSize),
                          SizedBox(width: isCompact ? 10 : 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: isCompact ? 15 : 18, fontWeight: FontWeight.w900)),
                            SizedBox(height: isCompact ? 2 : 4),
                            Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: isCompact ? 12 : 14)),
                            SizedBox(height: isCompact ? 6 : 8),
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              _StatusChip(text: roleLabel(trainerRole), color: context.gymPrimary),
                              _StatusChip(text: active ? 'Activo' : 'Desactivado', color: active ? context.gymPrimary : Colors.redAccent),
                            ]),
                          ])),
                          if (canManage)
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              iconSize: isCompact ? 22 : 24,
                              onSelected: (value) {
                                if (value == 'edit') editTrainer(doc.id, data);
                                if (value == 'toggle') toggleActive(doc.id, data);
                                if (value == 'reset') resendPasswordEmail(email);
                                if (value == 'delete') deleteTrainer(doc.id, data);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                PopupMenuItem(value: 'toggle', child: Text(active ? 'Desactivar' : 'Activar')),
                                const PopupMenuItem(value: 'reset', child: Text('Reenviar acceso')),
                                const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
                              ],
                            ),
                        ]),
                      );
                    }),
                ]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: isCompact ? 4 : 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: isCompact ? 11 : 12)),
    );
  }
}

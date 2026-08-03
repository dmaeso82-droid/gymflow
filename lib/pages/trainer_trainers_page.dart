
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../firebase_options.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/section_title.dart';

class TrainerTrainersPage extends StatefulWidget {
  final String gymId;
  final String trainerRole;

  const TrainerTrainersPage({
    super.key,
    required this.gymId,
    required this.trainerRole,
  });

  @override
  State<TrainerTrainersPage> createState() => _TrainerTrainersPageState();
}

class _TrainerTrainersPageState extends State<TrainerTrainersPage> {
  CollectionReference<Map<String, dynamic>> get trainersRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('trainers');

  bool get canManage => widget.trainerRole == 'gym_admin';

  void showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String temporaryPassword() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return 'GymFlow_${timestamp.substring(timestamp.length - 6)}!';
  }

  String roleLabel(String role) {
    switch (role) {
      case 'gym_admin':
        return 'Admin gimnasio';
      case 'trainer':
      default:
        return 'Entrenador';
    }
  }

  Future<UserCredential> createAuthTrainerAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'trainerCreator_${DateTime.now().microsecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(name);
      await secondaryAuth.signOut();
      return credential;
    } finally {
      await secondaryApp?.delete();
    }
  }

  Future<void> createTrainer() async {
    if (!canManage) {
      showSnack('Solo un admin de gimnasio puede crear entrenadores.');
      return;
    }

    final nameController = TextEditingController();
    final emailController = TextEditingController();
    var selectedRole = 'trainer';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              title: const Text('Nuevo entrenador'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTextField(controller: nameController, label: 'Nombre'),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
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
                        DropdownMenuItem(value: 'gym_admin', child: Text('Admin gimnasio')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedRole = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Se creará una cuenta de acceso y se enviará un email para establecer la contraseña.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
                FilledButton.icon(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final email = emailController.text.trim().toLowerCase();
                    if (name.isEmpty || email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Introduce nombre y email.')),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, {
                      'name': name,
                      'email': email,
                      'trainerRole': selectedRole,
                    });
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Crear entrenador'),
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

    final name = result['name']!;
    final email = result['email']!;
    final trainerRole = result['trainerRole']!;

    final existing = await trainersRef.where('email', isEqualTo: email).limit(1).get();
    if (existing.docs.isNotEmpty) {
      showSnack('Ya existe un entrenador con ese email.');
      return;
    }

    final password = temporaryPassword();
    UserCredential credential;
    try {
      credential = await createAuthTrainerAccount(name: name, email: email, password: password);
    } on FirebaseAuthException catch (e) {
      showSnack('No se pudo crear la cuenta: ${e.code}');
      return;
    } catch (e) {
      showSnack('No se pudo crear la cuenta: $e');
      return;
    }

    final uid = credential.user!.uid;
    final db = FirebaseFirestore.instance;
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentName = currentUser?.displayName ?? currentUser?.email ?? 'Admin';

    final batch = db.batch();
    batch.set(db.collection('gyms').doc(widget.gymId), {
      'name': defaultGymName,
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(db.collection('users').doc(uid), {
      'name': name,
      'email': email,
      'role': 'trainer',
      'trainerRole': trainerRole,
      'gymId': widget.gymId,
      'active': true,
      'createdBy': currentName,
      'createdByUid': currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(trainersRef.doc(uid), {
      'name': name,
      'email': email,
      'role': 'trainer',
      'trainerRole': trainerRole,
      'active': true,
      'createdBy': currentName,
      'createdByUid': currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(db.collection('gyms').doc(widget.gymId).collection('members').doc(uid), {
      'name': name,
      'email': email,
      'role': 'trainer',
      'trainerRole': trainerRole,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      showSnack('Entrenador creado. Se ha enviado el email para establecer contraseña.');
    } on FirebaseAuthException catch (e) {
      showSnack('Entrenador creado, pero no se pudo enviar el email: ${e.code}');
    }
  }

  Future<void> editTrainer(String uid, Map<String, dynamic> data) async {
    if (!canManage) {
      showSnack('Solo un admin de gimnasio puede editar entrenadores.');
      return;
    }

    final nameController = TextEditingController(text: data['name']?.toString() ?? '');
    var selectedRole = data['trainerRole']?.toString() ?? 'trainer';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              title: const Text('Editar entrenador'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(controller: nameController, label: 'Nombre'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    dropdownColor: const Color(0xFF0F172A),
                    decoration: const InputDecoration(labelText: 'Rol', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'trainer', child: Text('Entrenador')),
                      DropdownMenuItem(value: 'gym_admin', child: Text('Admin gimnasio')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedRole = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
                FilledButton.icon(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(dialogContext, {'name': name, 'trainerRole': selectedRole});
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
    if (result == null) return;

    final updated = {
      'name': result['name'],
      'trainerRole': result['trainerRole'],
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await Future.wait([
      trainersRef.doc(uid).update(updated),
      FirebaseFirestore.instance.collection('users').doc(uid).update(updated),
      FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('members').doc(uid).update(updated),
    ]);
    showSnack('Entrenador actualizado.');
  }

  Future<void> toggleActive(String uid, Map<String, dynamic> data) async {
    if (!canManage) {
      showSnack('Solo un admin de gimnasio puede activar o desactivar entrenadores.');
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.uid == uid) {
      showSnack('No puedes desactivar tu propia cuenta desde aquí.');
      return;
    }

    final active = data['active'] != false;
    final newActive = !active;
    final update = {
      'active': newActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await Future.wait([
      trainersRef.doc(uid).update(update),
      FirebaseFirestore.instance.collection('users').doc(uid).update(update),
      FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('members').doc(uid).update(update),
    ]);
    showSnack(newActive ? 'Entrenador activado.' : 'Entrenador desactivado.');
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
      appBar: AppBar(title: const Text('Entrenadores')),
      floatingActionButton: canManage
          ? isCompact
              ? FloatingActionButton(
                  onPressed: createTrainer,
                  child: const Icon(Icons.person_add),
                )
              : FloatingActionButton.extended(
                  onPressed: createTrainer,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Nuevo entrenador'),
                )
          : null,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: trainersRef.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final trainers = snapshot.data?.docs ?? [];
            return ListView(
              padding: EdgeInsets.all(pagePadding),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.groups, color: Colors.greenAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Equipo de entrenadores',
                            style: TextStyle(fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      SizedBox(height: isCompact ? 8 : 12),
                      Text(
                        canManage
                            ? isCompact
                                ? 'Gestiona el equipo de $defaultGymName.'
                                : 'Gestiona entrenadores de $defaultGymName. Todos comparten clientes, rutinas, objetivos y plantillas del gimnasio.'
                            : isCompact
                                ? 'Equipo del gimnasio.'
                                : 'Puedes ver el equipo de entrenadores. Solo un admin de gimnasio puede crear o editar entrenadores.',
                        style: TextStyle(color: Colors.white70, fontSize: isCompact ? 13 : 14),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isCompact ? 10 : 16),
                if (trainers.isEmpty)
                  const AppCard(
                    child: Text(
                      'Todavía no hay entrenadores registrados en este gimnasio.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                else
                  ...trainers.map((doc) {
                    final data = doc.data();
                    final name = data['name']?.toString() ?? 'Entrenador';
                    final email = data['email']?.toString() ?? '';
                    final trainerRole = data['trainerRole']?.toString() ?? 'trainer';
                    final active = data['active'] != false;

                    return AppCard(
                      margin: EdgeInsets.only(bottom: isCompact ? 8 : 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ProfileAvatar(name: name, size: avatarSize),
                          SizedBox(width: isCompact ? 10 : 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: isCompact ? 15 : 18, fontWeight: FontWeight.w900),
                                ),
                                SizedBox(height: isCompact ? 2 : 4),
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white60, fontSize: isCompact ? 12 : 14),
                                ),
                                SizedBox(height: isCompact ? 6 : 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isCompact ? 8 : 10,
                                        vertical: isCompact ? 4 : 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent.withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        roleLabel(trainerRole),
                                        style: TextStyle(fontSize: isCompact ? 11 : 12),
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isCompact ? 8 : 10,
                                        vertical: isCompact ? 4 : 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? Colors.greenAccent.withOpacity(0.14)
                                            : Colors.redAccent.withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        active ? 'Activo' : 'Desactivado',
                                        style: TextStyle(fontSize: isCompact ? 11 : 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (canManage)
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              iconSize: isCompact ? 22 : 24,
                              onSelected: (value) {
                                if (value == 'edit') editTrainer(doc.id, data);
                                if (value == 'toggle') toggleActive(doc.id, data);
                                if (value == 'reset') resendPasswordEmail(email);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                PopupMenuItem(value: 'toggle', child: Text(active ? 'Desactivar' : 'Activar')),
                                const PopupMenuItem(value: 'reset', child: Text('Reenviar acceso')),
                              ],
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

}
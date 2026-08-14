import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../firebase_options.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/info_chip.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/section_title.dart';

class TrainerClientsPage extends StatefulWidget {
  final String gymId;

  const TrainerClientsPage({super.key, required this.gymId});

  @override
  State<TrainerClientsPage> createState() => _TrainerClientsPageState();
}

class _TrainerClientsPageState extends State<TrainerClientsPage> {
  final clientNameController = TextEditingController();
  final clientEmailController = TextEditingController();
  final clientGoalController = TextEditingController();
  String searchText = '';

  CollectionReference<Map<String, dynamic>> get clientsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('clients');

  CollectionReference<Map<String, dynamic>> get routinesRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('routines');

  CollectionReference<Map<String, dynamic>> get activityRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('activity');

  @override
  void dispose() {
    clientNameController.dispose();
    clientEmailController.dispose();
    clientGoalController.dispose();
    super.dispose();
  }

  void showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<Map<String, String>> currentActor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {'uid': '', 'name': 'Sistema', 'email': ''};
    }

    var name = user.displayName ?? '';
    final email = (user.email ?? '').toLowerCase();

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = userDoc.data();
      final storedName = data?['name']?.toString() ?? '';
      if (storedName.trim().isNotEmpty) name = storedName.trim();
    } catch (_) {
      // Si no se puede leer el perfil, usamos el email para no bloquear la operación.
    }

    if (name.trim().isEmpty) name = email.isEmpty ? 'Entrenador' : email;
    return {'uid': user.uid, 'name': name, 'email': email};
  }

  Map<String, dynamic> auditCreateFields(Map<String, String> actor) {
    return {
      'createdBy': actor['name'] ?? '',
      'createdByUid': actor['uid'] ?? '',
      'updatedBy': actor['name'] ?? '',
      'updatedByUid': actor['uid'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> auditUpdateFields(Map<String, String> actor) {
    return {
      'updatedBy': actor['name'] ?? '',
      'updatedByUid': actor['uid'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> activityFields({
    required String type,
    required String target,
    required Map<String, String> actor,
    String? targetId,
    String? targetEmail,
    Map<String, dynamic>? metadata,
  }) {
    return {
      'type': type,
      'target': target,
      'targetId': targetId ?? '',
      'targetEmail': (targetEmail ?? '').toLowerCase(),
      'user': actor['name'] ?? '',
      'userUid': actor['uid'] ?? '',
      'userEmail': actor['email'] ?? '',
      'metadata': metadata ?? {},
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  String temporaryPassword() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return 'GymFlow_${timestamp.substring(timestamp.length - 6)}!';
  }

  Future<UserCredential?> createFirebaseClientAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'clientCreator_${DateTime.now().microsecondsSinceEpoch}',
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
    } on FirebaseAuthException catch (e) {
      debugPrint('FIREBASE AUTH ERROR al crear cliente');
      debugPrint('CODE: ${e.code}');
      debugPrint('MESSAGE: ${e.message}');
      rethrow;
    } finally {
      await secondaryApp?.delete();
    }
  }

  Future<void> addClient() async {
    final name = clientNameController.text.trim();
    final email = clientEmailController.text.trim().toLowerCase();
    final goal = clientGoalController.text.trim();

    if (name.isEmpty) {
      showSnack('Introduce el nombre del cliente.');
      return;
    }

    if (email.isEmpty) {
      showSnack('Introduce el email del cliente.');
      return;
    }

    final existingClient = await clientsRef.where('email', isEqualTo: email).limit(1).get();
    if (existingClient.docs.isNotEmpty) {
      showSnack('Ya existe un cliente con ese email.');
      return;
    }

    final tempPassword = temporaryPassword();
    UserCredential? createdCredential;

    try {
      createdCredential = await createFirebaseClientAccount(
        name: name,
        email: email,
        password: tempPassword,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('FIREBASE AUTH ERROR al crear cliente');
      debugPrint('CODE: ${e.code}');
      debugPrint('MESSAGE: ${e.message}');
      final message = e.code == 'email-already-in-use'
          ? 'Ese email ya existe en Firebase Authentication. Borra esa cuenta en Firebase Auth o usa otro correo.'
          : 'No se pudo crear la cuenta de acceso: ${e.code}';
      showSnack(message);
      return;
    } catch (e) {
      debugPrint('ERROR GENERAL al crear cliente: $e');
      showSnack('No se pudo crear la cuenta de acceso: $e');
      return;
    }

    final uid = createdCredential?.user?.uid;
    if (uid == null || uid.isEmpty) {
      showSnack('No se creó la cuenta en Firebase Authentication. No se guardará el cliente.');
      return;
    }
    final actor = await currentActor();
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final clientDoc = clientsRef.doc();

    batch.set(clientDoc, {
      'name': name,
      'email': email,
      'goal': goal.isEmpty ? 'Objetivo pendiente' : goal,
      'level': 'Nuevo',
      'authUid': uid,
      'accountStatus': 'invited',
      ...auditCreateFields(actor),
    });

    batch.set(db.collection('users').doc(uid), {
        'name': name,
        'email': email,
        'role': 'user',
        'gymId': widget.gymId,
        'active': true,
        'createdByTrainer': true,
        'createdBy': actor['name'] ?? '',
        'createdByUid': actor['uid'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

    batch.set(db.collection('gyms').doc(widget.gymId).collection('members').doc(uid), {
        'name': name,
        'email': email,
        'role': 'user',
        'active': true,
        'createdBy': actor['name'] ?? '',
        'createdByUid': actor['uid'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

    batch.set(activityRef.doc(), activityFields(
      type: 'client_created',
      target: name,
      targetId: clientDoc.id,
      targetEmail: email,
      actor: actor,
      metadata: {'goal': goal.isEmpty ? 'Objetivo pendiente' : goal},
    ));

    await batch.commit();

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      showSnack('Cliente creado. Se ha enviado un email para establecer la contraseña.');
    } on FirebaseAuthException catch (e) {
      showSnack('Cliente creado, pero no se pudo enviar el email de contraseña: ${e.code}');
    }

    clientNameController.clear();
    clientEmailController.clear();
    clientGoalController.clear();
  }

  Future<void> editClient(String clientId, Map<String, dynamic> clientData) async {
    final nameController = TextEditingController(text: clientData['name']?.toString() ?? '');
    final emailController = TextEditingController(text: clientData['email']?.toString() ?? '');
    final goalController = TextEditingController(text: clientData['goal']?.toString() ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.gymSurface,
          title: Text('Editar cliente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(controller: nameController, label: 'Nombre del cliente'),
              SizedBox(height: 12),
              AppTextField(
                controller: emailController,
                label: 'Email del cliente',
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 12),
              AppTextField(controller: goalController, label: 'Objetivo'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancelar')),
            FilledButton.icon(
              onPressed: () {
                final name = nameController.text.trim();
                final email = emailController.text.trim().toLowerCase();
                final goal = goalController.text.trim();

                if (name.isEmpty || email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Introduce nombre y email del cliente.')),
                  );
                  return;
                }

                Navigator.pop(dialogContext, {
                  'name': name,
                  'email': email,
                  'goal': goal.isEmpty ? 'Objetivo pendiente' : goal,
                });
              },
              icon: Icon(Icons.save),
              label: Text('Guardar'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    goalController.dispose();

    if (result == null) return;

    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(clientsRef.doc(clientId), {
      'name': result['name'],
      'email': result['email'],
      'goal': result['goal'],
      ...auditUpdateFields(actor),
    });

    final relatedRoutines = await routinesRef.where('clientId', isEqualTo: clientId).get();
    for (final routine in relatedRoutines.docs) {
      batch.update(routine.reference, {
        'clientName': result['name'],
        'clientEmail': result['email'],
        ...auditUpdateFields(actor),
      });
    }

    batch.set(activityRef.doc(), activityFields(
      type: 'client_updated',
      target: result['name'] ?? clientData['name']?.toString() ?? 'Cliente',
      targetId: clientId,
      targetEmail: result['email'],
      actor: actor,
      metadata: {
        'previousName': clientData['name'] ?? '',
        'previousEmail': clientData['email'] ?? '',
      },
    ));

    await batch.commit();
    showSnack('Cliente actualizado. Rutinas asociadas sincronizadas.');
  }

  String firestoreSafeKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  CollectionReference<Map<String, dynamic>> gymCollection(String name) {
    return FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection(name);
  }

  Future<int> deleteQueryDocuments(Query<Map<String, dynamic>> query) async {
    try {
      final snapshot = await query.get();
      var deleted = 0;
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
        deleted++;
      }
      return deleted;
    } catch (error) {
      debugPrint('No se pudo limpiar una consulta relacionada con cliente: $error');
      return 0;
    }
  }

  Future<int> deleteDocumentIfExists(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      final snapshot = await ref.get();
      if (!snapshot.exists) return 0;
      await ref.delete();
      return 1;
    } catch (error) {
      debugPrint('No se pudo eliminar documento relacionado con cliente: $error');
      return 0;
    }
  }

  Future<int> deleteProgressPhotosForClient({required String authUid, required String email}) async {
    final deletedPhotoIds = <String>{};
    var deleted = 0;

    Future<void> deletePhotosFromQuery(Query<Map<String, dynamic>> query) async {
      try {
        final snapshot = await query.get();
        for (final doc in snapshot.docs) {
          if (!deletedPhotoIds.add(doc.id)) continue;
          final data = doc.data();
          final storagePath = data['storagePath']?.toString() ?? '';
          if (storagePath.isNotEmpty) {
            try {
              await FirebaseStorage.instance.ref(storagePath).delete();
            } catch (error) {
              debugPrint('No se pudo eliminar imagen de Storage: $error');
            }
          }
          await doc.reference.delete();
          deleted++;
        }
      } catch (error) {
        debugPrint('No se pudieron limpiar fotos de progreso del cliente: $error');
      }
    }

    if (authUid.isNotEmpty) {
      await deletePhotosFromQuery(gymCollection('progress_photos').where('userId', isEqualTo: authUid));
    }
    if (email.isNotEmpty) {
      await deletePhotosFromQuery(gymCollection('progress_photos').where('userEmail', isEqualTo: email));
    }
    return deleted;
  }

  Future<int> deleteClientRelatedData({
    required String clientId,
    required Map<String, dynamic> clientData,
  }) async {
    final authUid = clientData['authUid']?.toString().trim() ?? '';
    final email = (clientData['email'] ?? '').toString().trim().toLowerCase();
    final emailKey = email.isEmpty ? '' : firestoreSafeKey(email);
    var deleted = 0;

    if (authUid.isNotEmpty) {
      deleted += await deleteDocumentIfExists(FirebaseFirestore.instance.collection('users').doc(authUid));
      deleted += await deleteDocumentIfExists(gymCollection('members').doc(authUid));
    }

    final knownDocKeys = <String>{
      clientId,
      if (authUid.isNotEmpty) authUid,
      if (emailKey.isNotEmpty) emailKey,
    };

    for (final key in knownDocKeys) {
      deleted += await deleteDocumentIfExists(gymCollection('user_stats').doc(key));
      deleted += await deleteDocumentIfExists(gymCollection('leaderboard').doc(key));
      deleted += await deleteDocumentIfExists(gymCollection('ranking_stats').doc(key));
      deleted += await deleteDocumentIfExists(gymCollection('progress_photo_settings').doc(key));
    }

    deleted += await deleteProgressPhotosForClient(authUid: authUid, email: email);

    final collectionsToClean = [
      'workout_logs',
      'goals',
      'measurements',
      'user_achievements',
      'points_ledger',
      'notifications',
      'community_posts',
      'ranking_stats',
      'leaderboard',
      'user_stats',
      'progress_photo_settings',
      'routines',
    ];

    for (final collectionName in collectionsToClean) {
      final collection = gymCollection(collectionName);
      deleted += await deleteQueryDocuments(collection.where('clientId', isEqualTo: clientId));
      if (authUid.isNotEmpty) {
        deleted += await deleteQueryDocuments(collection.where('userId', isEqualTo: authUid));
        deleted += await deleteQueryDocuments(collection.where('authUid', isEqualTo: authUid));
      }
      if (email.isNotEmpty) {
        deleted += await deleteQueryDocuments(collection.where('email', isEqualTo: email));
        deleted += await deleteQueryDocuments(collection.where('userEmail', isEqualTo: email));
        deleted += await deleteQueryDocuments(collection.where('clientEmail', isEqualTo: email));
        deleted += await deleteQueryDocuments(collection.where('targetEmail', isEqualTo: email));
      }
    }

    return deleted;
  }

  Future<void> deleteClient(String clientId, Map<String, dynamic> clientData) async {
    final clientName = clientData['name']?.toString() ?? 'este cliente';
    final clientEmail = (clientData['email'] ?? '').toString().trim().toLowerCase();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.gymSurface,
          title: Text('Eliminar cliente'),
          content: Text(
            '¿Seguro que quieres eliminar a $clientName? Se eliminará su ficha y también sus datos asociados en Firestore: rutinas, entrenamientos, objetivos, medidas, fotos, logros, puntos, ranking y notificaciones. Esta acción no elimina automáticamente la cuenta de Firebase Authentication.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('Cancelar')),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: Icon(Icons.delete_outline),
              label: Text('Eliminar todo'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    final actor = await currentActor();
    final deletedRelatedDocs = await deleteClientRelatedData(clientId: clientId, clientData: clientData);

    final batch = FirebaseFirestore.instance.batch();
    batch.delete(clientsRef.doc(clientId));
    batch.set(activityRef.doc(), activityFields(
      type: 'client_deleted',
      target: clientName,
      targetId: clientId,
      targetEmail: clientEmail,
      actor: actor,
      metadata: {
        'deletedRelatedDocs': deletedRelatedDocs,
        'authUid': clientData['authUid']?.toString() ?? '',
        'hardDelete': true,
      },
    ));
    await batch.commit();
    showSnack('Cliente eliminado. También se han limpiado $deletedRelatedDocs documentos asociados.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Clientes')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(icon: Icons.person_add, title: 'Crear cliente'),
                  SizedBox(height: 12),
                  AppTextField(controller: clientNameController, label: 'Nombre del cliente'),
                  SizedBox(height: 12),
                  AppTextField(
                    controller: clientEmailController,
                    label: 'Email del cliente',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 12),
                  AppTextField(
                    controller: clientGoalController,
                    label: 'Objetivo',
                    hint: 'Ej: Fuerza, pérdida de grasa...',
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: addClient,
                      icon: Icon(Icons.add),
                      label: Text('Crear cliente y enviar acceso'),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            TextField(
              onChanged: (value) => setState(() => searchText = value),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar cliente',
                filled: true,
                fillColor: context.gymSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: context.gymBorder),
                ),
              ),
            ),
            SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: clientsRef.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final clients = (snapshot.data?.docs ?? []).where((doc) {
                  final data = doc.data();
                  final text = '${data['name'] ?? ''} ${data['email'] ?? ''} ${data['goal'] ?? ''}'.toLowerCase();
                  return text.contains(searchText.toLowerCase());
                }).toList();

                if (clients.isEmpty) {
                  return AppCard(child: Text('No hay clientes que coincidan con la búsqueda.'));
                }

                return Column(
                  children: clients.map((doc) {
                    final data = doc.data();
                    final name = data['name']?.toString() ?? 'Sin nombre';
                    final email = data['email']?.toString() ?? 'Sin email';
                    final goal = data['goal']?.toString() ?? 'Objetivo pendiente';

                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ProfileAvatar(name: name),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                    SizedBox(height: 4),
                                    Text(email, style: TextStyle(color: context.gymMutedText)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              InfoChip(text: goal),
                              if ((data['createdBy'] ?? '').toString().isNotEmpty)
                                InfoChip(text: 'Creado por ${data['createdBy']}'),
                              if ((data['updatedBy'] ?? '').toString().isNotEmpty)
                                InfoChip(text: 'Actualizado por ${data['updatedBy']}'),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => editClient(doc.id, data),
                                  icon: Icon(Icons.edit),
                                  label: Text('Editar'),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                                  onPressed: () => deleteClient(doc.id, data),
                                  icon: Icon(Icons.delete_outline),
                                  label: Text('Eliminar'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}




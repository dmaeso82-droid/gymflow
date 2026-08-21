import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../firebase_options.dart';
import '../services/subscription_service.dart';
import '../services/member_provisioning_service.dart';
import '../services/secure_deletion_service.dart';
import '../services/secure_update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/info_chip.dart';
import '../widgets/profile_avatar.dart';

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
  bool creatingClient = false;

  CollectionReference<Map<String, dynamic>> get clientsRef => FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('clients');
  CollectionReference<Map<String, dynamic>> get routinesRef => FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('routines');
  CollectionReference<Map<String, dynamic>> get activityRef => FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('activity');
  DocumentReference<Map<String, dynamic>> get gymRef => FirebaseFirestore.instance.collection('gyms').doc(widget.gymId);
  DocumentReference<Map<String, dynamic>> get subscriptionRef => FirebaseFirestore.instance.collection('subscriptions').doc(widget.gymId);
  SubscriptionService get subscriptionService => SubscriptionService(gymId: widget.gymId);

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
    if (user == null) return {'uid': '', 'name': 'Sistema', 'email': ''};
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
    return {'updatedBy': actor['name'] ?? '', 'updatedByUid': actor['uid'] ?? '', 'updatedAt': FieldValue.serverTimestamp()};
  }

  Map<String, dynamic> activityFields({required String type, required String target, required Map<String, String> actor, String? targetId, String? targetEmail, Map<String, dynamic>? metadata}) {
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

  int clientLimitForPlan(String plan) {
    switch (plan) {
      case 'enterprise':
        return 999999;
      case 'pro':
        return 500;
      case 'starter':
      default:
        return 50;
    }
  }

  Future<bool> canCreateAnotherClient() async {
    final subscriptionPlan = await subscriptionService.loadPlan();
    if (!subscriptionPlan.isActive) {
      showSnack('La suscripción del gimnasio no está activa. No se pueden crear clientes.');
      return false;
    }
    final subscription = await subscriptionRef.get();
    final plan = subscription.data()?['plan']?.toString() ?? defaultSubscriptionPlan;
    final limit = clientLimitForPlan(plan);
    if (limit >= 999999) return true;
    final current = await clientsRef.get();
    if (current.docs.length >= limit) {
      showSnack('El plan $plan permite hasta $limit clientes.');
      return false;
    }
    return true;
  }

  Future<UserCredential?> createFirebaseClientAccount({required String name, required String email, required String password}) async {
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(name: 'clientCreator_${DateTime.now().microsecondsSinceEpoch}', options: DefaultFirebaseOptions.currentPlatform);
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(email: email, password: password);
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
    if (creatingClient) return;
    final name = clientNameController.text.trim();
    final email = clientEmailController.text.trim().toLowerCase();
    final goal = clientGoalController.text.trim();
    if (name.isEmpty || email.isEmpty) {
      showSnack('Introduce el nombre y el email del cliente.');
      return;
    }
    setState(() => creatingClient = true);
    try {
      await MemberProvisioningService(gymId: widget.gymId).createClient(
        name: name, email: email, goal: goal,
      );
      if (!mounted) return;
      clientNameController.clear();
      clientEmailController.clear();
      clientGoalController.clear();
      showSnack('Cliente creado. Se ha enviado el email para establecer la contraseña.');
    } catch (error) {
      if (!mounted) return;
      showSnack(MemberProvisioningService(gymId: widget.gymId).messageForError(error));
    } finally {
      if (mounted) setState(() => creatingClient = false);
    }
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
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            AppTextField(controller: nameController, label: 'Nombre del cliente'),
            SizedBox(height: 12),
            AppTextField(controller: emailController, label: 'Email del cliente', keyboardType: TextInputType.emailAddress),
            SizedBox(height: 12),
            AppTextField(controller: goalController, label: 'Objetivo'),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancelar')),
            FilledButton.icon(
              onPressed: () {
                final name = nameController.text.trim();
                final email = emailController.text.trim().toLowerCase();
                final goal = goalController.text.trim();
                if (name.isEmpty || email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Introduce nombre y email del cliente.')));
                  return;
                }
                Navigator.pop(dialogContext, {'name': name, 'email': email, 'goal': goal.isEmpty ? 'Objetivo pendiente' : goal});
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
    final service = SecureUpdateService(gymId: widget.gymId);
    try {
      await service.updateClient(clientId: clientId, name: result['name']!, email: result['email']!, goal: result['goal']!);
      if (!mounted) return;
      showSnack('Cliente actualizado. Rutinas asociadas sincronizadas.');
    } catch (error) {
      if (!mounted) return;
      showSnack(service.messageForError(error));
    }
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
    if (authUid.isNotEmpty) await deletePhotosFromQuery(gymCollection('progress_photos').where('userId', isEqualTo: authUid));
    if (email.isNotEmpty) await deletePhotosFromQuery(gymCollection('progress_photos').where('userEmail', isEqualTo: email));
    return deleted;
  }

  Future<int> deleteClientRelatedData({required String clientId, required Map<String, dynamic> clientData}) async {
    final authUid = clientData['authUid']?.toString().trim() ?? '';
    final email = (clientData['email'] ?? '').toString().trim().toLowerCase();
    final emailKey = email.isEmpty ? '' : firestoreSafeKey(email);
    var deleted = 0;
    if (authUid.isNotEmpty) {
      deleted += await deleteDocumentIfExists(FirebaseFirestore.instance.collection('users').doc(authUid));
      deleted += await deleteDocumentIfExists(gymCollection('members').doc(authUid));
    }
    final knownDocKeys = <String>{clientId, if (authUid.isNotEmpty) authUid, if (emailKey.isNotEmpty) emailKey};
    for (final key in knownDocKeys) {
      deleted += await deleteDocumentIfExists(gymCollection('user_stats').doc(key));
      deleted += await deleteDocumentIfExists(gymCollection('leaderboard').doc(key));
      deleted += await deleteDocumentIfExists(gymCollection('ranking_stats').doc(key));
      deleted += await deleteDocumentIfExists(gymCollection('progress_photo_settings').doc(key));
    }
    deleted += await deleteProgressPhotosForClient(authUid: authUid, email: email);
    final collectionsToClean = ['workout_logs', 'goals', 'measurements', 'user_achievements', 'points_ledger', 'notifications', 'community_posts', 'ranking_stats', 'leaderboard', 'user_stats', 'progress_photo_settings', 'routines'];
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.gymSurface,
        title: const Text('Eliminar cliente'),
        content: Text('¿Seguro que quieres eliminar a $clientName? Se eliminarán su cuenta de acceso y todos sus datos asociados. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar todo'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final service = SecureDeletionService(gymId: widget.gymId);
    try {
      final result = await service.deleteClient(clientId);
      if (!mounted) return;
      showSnack('Cliente eliminado. Se limpiaron ${result.deletedRelatedDocs} documentos asociados.');
    } catch (error) {
      if (!mounted) return;
      showSnack(service.messageForError(error));
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton.extended(onPressed: creatingClient ? null : addClient, icon: creatingClient ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.person_add_alt_1_rounded), label: const Text('Crear cliente')),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: gymRef.snapshots(),
          builder: (context, gymSnapshot) {
            final gymName = gymSnapshot.data?.data()?['name']?.toString() ?? defaultGymName;
            final plan = gymSnapshot.data?.data()?['plan']?.toString() ?? defaultSubscriptionPlan;
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: clientsRef.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: context.gymPrimary));
                final allClients = snapshot.data?.docs ?? [];
                final filteredClients = allClients.where((doc) {
                  final data = doc.data();
                  final text = '${data['name'] ?? ''} ${data['email'] ?? ''} ${data['goal'] ?? ''}'.toLowerCase();
                  return text.contains(searchText.toLowerCase());
                }).toList();
                return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
                  _TrainerClientsHero(totalClients: allClients.length, visibleClients: filteredClients.length, gymName: gymName, plan: plan),
                  const SizedBox(height: 12),
                  _CreateClientPanel(nameController: clientNameController, emailController: clientEmailController, goalController: clientGoalController, onCreate: addClient, creating: creatingClient),
                  const SizedBox(height: 12),
                  _TrainerSearchField(hint: 'Buscar cliente', onChanged: (value) => setState(() => searchText = value)),
                  const SizedBox(height: 12),
                  if (filteredClients.isEmpty)
                    _TrainerEmptyState(icon: Icons.people_outline_rounded, title: 'No hay clientes que coincidan', subtitle: 'Prueba con otro nombre, email u objetivo.')
                  else
                    ...filteredClients.map((doc) {
                      final data = doc.data();
                      return _TrainerClientTile(
                        name: data['name']?.toString() ?? 'Sin nombre',
                        email: data['email']?.toString() ?? 'Sin email',
                        goal: data['goal']?.toString() ?? 'Objetivo pendiente',
                        createdBy: (data['createdBy'] ?? '').toString(),
                        updatedBy: (data['updatedBy'] ?? '').toString(),
                        onEdit: () => editClient(doc.id, data),
                        onDelete: () => deleteClient(doc.id, data),
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

class _TrainerClientsHero extends StatelessWidget {
  final int totalClients;
  final int visibleClients;
  final String gymName;
  final String plan;
  const _TrainerClientsHero({required this.totalClients, required this.visibleClients, required this.gymName, required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(28)),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(19)), child: Icon(Icons.people_alt_rounded, color: context.gymPrimary, size: 25)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Clientes', style: TextStyle(color: context.gymText, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
          const SizedBox(height: 4),
          Text('$gymName · $visibleClients visibles · $totalClients totales · plan $plan', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ])),
      ]),
    );
  }
}

class _CreateClientPanel extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController goalController;
  final VoidCallback onCreate;
  final bool creating;
  const _CreateClientPanel({required this.nameController, required this.emailController, required this.goalController, required this.onCreate, required this.creating});

  @override
  State<_CreateClientPanel> createState() => _CreateClientPanelState();
}

class _CreateClientPanelState extends State<_CreateClientPanel> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => setState(() => expanded = !expanded),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(24)),
            child: Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(17)), child: Icon(Icons.person_add_alt_1_rounded, color: context.gymPrimary, size: 21)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Crear cliente', style: TextStyle(color: context.gymText, fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('Alta rápida con acceso por email', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
              ])),
              Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: context.gymPrimary),
            ]),
          ),
        ),
      ),
      if (expanded) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.34 : 0.52), borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            AppTextField(controller: widget.nameController, label: 'Nombre del cliente'),
            const SizedBox(height: 12),
            AppTextField(controller: widget.emailController, label: 'Email del cliente', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            AppTextField(controller: widget.goalController, label: 'Objetivo', hint: 'Ej: Fuerza, pérdida de grasa...'),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: widget.creating ? null : widget.onCreate, icon: widget.creating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_rounded), label: const Text('CREAR CLIENTE Y ENVIAR ACCESO'))),
          ]),
        ),
      ],
    ]);
  }
}

class _TrainerSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const _TrainerSearchField({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: hint, filled: true, fillColor: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.44 : 0.68), border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: context.gymPrimary.withValues(alpha: 0.55), width: 1.2))),
    );
  }
}

class _TrainerClientTile extends StatelessWidget {
  final String name;
  final String email;
  final String goal;
  final String createdBy;
  final String updatedBy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _TrainerClientTile({required this.name, required this.email, required this.goal, required this.createdBy, required this.updatedBy, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
      decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.46 : 0.68), borderRadius: BorderRadius.circular(26)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ProfileAvatar(name: name, size: 46),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
          ])),
          IconButton(tooltip: 'Editar', onPressed: onEdit, icon: Icon(Icons.edit_rounded, color: context.gymPrimary)),
          IconButton(tooltip: 'Eliminar', onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [InfoChip(text: goal), if (createdBy.isNotEmpty) InfoChip(text: 'Creado por $createdBy'), if (updatedBy.isNotEmpty) InfoChip(text: 'Actualizado por $updatedBy')]),
      ]),
    );
  }
}

class _TrainerEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _TrainerEmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(26)),
      child: Column(children: [
        Icon(icon, color: context.gymPrimary, size: 34),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: TextStyle(color: context.gymText, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

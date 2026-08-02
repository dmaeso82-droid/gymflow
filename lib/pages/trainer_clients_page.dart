import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

    await clientsRef.add({
      'name': name,
      'email': email,
      'goal': goal.isEmpty ? 'Objetivo pendiente' : goal,
      'level': 'Nuevo',
      'createdAt': FieldValue.serverTimestamp(),
    });

    clientNameController.clear();
    clientEmailController.clear();
    clientGoalController.clear();
    showSnack('Cliente creado.');
  }

  Future<void> editClient(String clientId, Map<String, dynamic> clientData) async {
    final nameController = TextEditingController(text: clientData['name']?.toString() ?? '');
    final emailController = TextEditingController(text: clientData['email']?.toString() ?? '');
    final goalController = TextEditingController(text: clientData['goal']?.toString() ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Editar cliente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(controller: nameController, label: 'Nombre del cliente'),
              const SizedBox(height: 12),
              AppTextField(
                controller: emailController,
                label: 'Email del cliente',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              AppTextField(controller: goalController, label: 'Objetivo'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
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
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    goalController.dispose();

    if (result == null) return;

    final batch = FirebaseFirestore.instance.batch();
    batch.update(clientsRef.doc(clientId), {
      'name': result['name'],
      'email': result['email'],
      'goal': result['goal'],
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final relatedRoutines = await routinesRef.where('clientId', isEqualTo: clientId).get();
    for (final routine in relatedRoutines.docs) {
      batch.update(routine.reference, {
        'clientName': result['name'],
        'clientEmail': result['email'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    showSnack('Cliente actualizado. Rutinas asociadas sincronizadas.');
  }

  Future<void> deleteClient(String clientId, Map<String, dynamic> clientData) async {
    final clientName = clientData['name']?.toString() ?? 'este cliente';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Eliminar cliente'),
          content: Text(
            '¿Seguro que quieres eliminar a $clientName? No se eliminarán sus rutinas ni sus entrenamientos, solo la ficha del cliente.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await clientsRef.doc(clientId).delete();
    showSnack('Cliente eliminado. Sus rutinas y entrenamientos se han conservado.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(icon: Icons.person_add, title: 'Crear cliente'),
                  const SizedBox(height: 12),
                  AppTextField(controller: clientNameController, label: 'Nombre del cliente'),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: clientEmailController,
                    label: 'Email del cliente',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: clientGoalController,
                    label: 'Objetivo',
                    hint: 'Ej: Fuerza, pérdida de grasa...',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: addClient,
                      icon: const Icon(Icons.add),
                      label: const Text('Crear cliente'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => setState(() => searchText = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar cliente',
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: clientsRef.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final clients = (snapshot.data?.docs ?? []).where((doc) {
                  final data = doc.data();
                  final text = '${data['name'] ?? ''} ${data['email'] ?? ''} ${data['goal'] ?? ''}'.toLowerCase();
                  return text.contains(searchText.toLowerCase());
                }).toList();

                if (clients.isEmpty) {
                  return const AppCard(child: Text('No hay clientes que coincidan con la búsqueda.'));
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
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(email, style: const TextStyle(color: Colors.white70)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              InfoChip(text: goal),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => editClient(doc.id, data),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Editar'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                                  onPressed: () => deleteClient(doc.id, data),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Eliminar'),
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

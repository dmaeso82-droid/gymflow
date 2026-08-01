import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/body_measurements.dart';
import '../features/client_progress.dart';
import '../sheets/exercise_sheet.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/header_card.dart';
import '../widgets/routine_card.dart';
import '../widgets/section_title.dart';

class TrainerHomePage extends StatefulWidget {
  final String gymId;
  final String trainerName;

  const TrainerHomePage({super.key, required this.gymId, required this.trainerName});

  @override
  State<TrainerHomePage> createState() => _TrainerHomePageState();
}

class _TrainerHomePageState extends State<TrainerHomePage> {
  final clientNameController = TextEditingController();
  final clientEmailController = TextEditingController();
  final clientGoalController = TextEditingController();
  final routineTitleController = TextEditingController();

  String? selectedClientId;
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
    routineTitleController.dispose();
    super.dispose();
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

    final doc = await clientsRef.add({
      'name': name,
      'email': email,
      'goal': goal.isEmpty ? 'Objetivo pendiente' : goal,
      'level': 'Nuevo',
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      selectedClientId = doc.id;
      clientNameController.clear();
      clientEmailController.clear();
      clientGoalController.clear();
    });
  }


  QueryDocumentSnapshot<Map<String, dynamic>>? selectedClientDocument(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> clients,
  ) {
    if (selectedClientId == null) return null;

    for (final doc in clients) {
      if (doc.id == selectedClientId) {
        return doc;
      }
    }

    return null;
  }

  Future<void> editClient(
    String clientId,
    Map<String, dynamic> clientData,
  ) async {
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
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                final name = nameController.text.trim();
                final email = emailController.text.trim().toLowerCase();
                final goal = goalController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Introduce el nombre del cliente.')),
                  );
                  return;
                }

                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Introduce el email del cliente.')),
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
    final clientRef = clientsRef.doc(clientId);

    batch.update(clientRef, {
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

  Future<void> deleteClient(
    String clientId,
    Map<String, dynamic> clientData,
  ) async {
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
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
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

    if (selectedClientId == clientId) {
      setState(() => selectedClientId = null);
    }

    showSnack('Cliente eliminado. Sus rutinas y entrenamientos se han conservado.');
  }

  Future<void> addRoutine(List<QueryDocumentSnapshot<Map<String, dynamic>>> clients) async {
    final title = routineTitleController.text.trim();

    if (title.isEmpty) {
      showSnack('Introduce el nombre de la rutina.');
      return;
    }

    if (selectedClientId == null) {
      showSnack('Selecciona un cliente.');
      return;
    }

	if (clients.isEmpty) {
		showSnack('No hay clientes.');
		return;
	}

	QueryDocumentSnapshot<Map<String, dynamic>> selectedClientDoc =
		clients.first;

	for (final doc in clients) {
		if (doc.id == selectedClientId) {
			selectedClientDoc = doc;
			break;
		}
	}
    final selectedClient = selectedClientDoc.data();

    await routinesRef.add({
      'title': title,
      'clientId': selectedClientDoc.id,
      'clientName': selectedClient['name'] ?? 'Sin cliente',
      'clientEmail': (selectedClient['email'] ?? '').toString().toLowerCase(),
      'day': 'Nuevo día',
      'notes': 'Añade observaciones para el usuario.',
      'exercises': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    routineTitleController.clear();
  }


  Future<void> editRoutine(String routineId, Map<String, dynamic> routineData) async {
    final titleController = TextEditingController(text: routineData['title']?.toString() ?? '');
    final dayController = TextEditingController(text: routineData['day']?.toString() ?? '');
    final notesController = TextEditingController(text: routineData['notes']?.toString() ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Editar rutina'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(controller: titleController, label: 'Nombre de la rutina'),
              const SizedBox(height: 12),
              AppTextField(controller: dayController, label: 'Día'),
              const SizedBox(height: 12),
              AppTextField(controller: notesController, label: 'Notas'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Introduce el nombre de la rutina.')),
                  );
                  return;
                }

                Navigator.pop(dialogContext, {
                  'title': title,
                  'day': dayController.text.trim().isEmpty ? 'Sin día' : dayController.text.trim(),
                  'notes': notesController.text.trim(),
                });
              },
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    dayController.dispose();
    notesController.dispose();

    if (result == null) return;

    await routinesRef.doc(routineId).update({
      'title': result['title'],
      'day': result['day'],
      'notes': result['notes'],
      'updatedAt': FieldValue.serverTimestamp(),
    });

    showSnack('Rutina actualizada.');
  }

  Future<void> deleteRoutine(String routineId, String routineTitle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Eliminar rutina'),
          content: Text('¿Seguro que quieres eliminar la rutina "$routineTitle"? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
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

    await routinesRef.doc(routineId).delete();
    showSnack('Rutina eliminada.');
  }

  Future<void> addExercise(String routineId, List<dynamic> currentExercises) async {
    final result = await showExerciseSheet(context);
    if (result == null) return;

    final newExercise = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': result.name,
      'sets': result.sets,
      'reps': result.reps,
      'weight': result.weight,
      'rest': result.rest,
      'done': false,
    };

    await routinesRef.doc(routineId).update({
      'exercises': [...currentExercises, newExercise],
    });
  }


  Future<void> editExercise(String routineId, List<dynamic> exercises, String exerciseId) async {
    Map<String, dynamic>? currentExercise;

    for (final item in exercises) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id'] == exerciseId) {
        currentExercise = map;
        break;
      }
    }

    if (currentExercise == null) {
      showSnack('No se ha encontrado el ejercicio.');
      return;
    }

    final result = await showExerciseSheet(context, initialExercise: currentExercise);
    if (result == null) return;

    final updated = exercises.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id'] == exerciseId) {
        return {
          ...map,
          'name': result.name,
          'sets': result.sets,
          'reps': result.reps,
          'weight': result.weight,
          'rest': result.rest,
        };
      }
      return map;
    }).toList();

    await routinesRef.doc(routineId).update({
      'exercises': updated,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    showSnack('Ejercicio actualizado.');
  }

  Future<void> updateExerciseDone(String routineId, List<dynamic> exercises, String exerciseId, bool done) async {
    final updated = exercises.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id'] == exerciseId) map['done'] = done;
      return map;
    }).toList();

    await routinesRef.doc(routineId).update({'exercises': updated});
  }

  Future<void> deleteExercise(String routineId, List<dynamic> exercises, String exerciseId) async {
    final updated = exercises.where((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return map['id'] != exerciseId;
    }).toList();

    await routinesRef.doc(routineId).update({'exercises': updated});
  }

  void showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GymFlow · ${widget.trainerName}'),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const HeaderCard(subtitle: 'Panel de entrenador'),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: clientsRef.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, clientSnapshot) {
                final clients = clientSnapshot.data?.docs ?? [];

                if (selectedClientId == null && clients.isNotEmpty) {
                  selectedClientId = clients.first.id;
                }

                return Column(
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
                          const SizedBox(height: 16),
                          if (clients.isNotEmpty)
                            DropdownButtonFormField<String>(
                              value: selectedClientId,
                              dropdownColor: const Color(0xFF0F172A),
                              decoration: const InputDecoration(
                                labelText: 'Cliente seleccionado',
                                border: OutlineInputBorder(),
                              ),
                              items: clients.map((doc) {
                                final data = doc.data();
                                final name = data['name'] ?? 'Sin nombre';
                                final email = data['email'] ?? 'Sin email';
                                return DropdownMenuItem(
                                  value: doc.id,
                                  child: Text('$name · $email'),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => selectedClientId = value),
                            ),
                          if (clients.isNotEmpty && selectedClientId != null) ...[
                            const SizedBox(height: 12),
                            Builder(
                              builder: (context) {
                                final selectedDoc = selectedClientDocument(clients);
                                if (selectedDoc == null) return const SizedBox.shrink();
                                final selectedClient = selectedDoc.data();

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Objetivo: ${selectedClient['goal'] ?? 'Objetivo pendiente'}',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => editClient(selectedDoc.id, selectedClient),
                                            icon: const Icon(Icons.edit),
                                            label: const Text('Editar cliente'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => deleteClient(selectedDoc.id, selectedClient),
                                            icon: const Icon(Icons.delete_outline),
                                            label: const Text('Eliminar cliente'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle(icon: Icons.playlist_add, title: 'Crear rutina'),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: routineTitleController,
                            label: 'Nombre de la rutina',
                            hint: 'Ej: Pecho y tríceps',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: clients.isEmpty ? null : () => addRoutine(clients),
                              icon: const Icon(Icons.add),
                              label: const Text('Crear rutina'),
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
                        hintText: 'Buscar rutina o cliente',
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (clients.isNotEmpty && selectedClientId != null)
                      Builder(
                        builder: (context) {
                          QueryDocumentSnapshot<Map<String, dynamic>> selectedClientDoc = clients.first;

                          for (final doc in clients) {
                            if (doc.id == selectedClientId) {
                              selectedClientDoc = doc;
                              break;
                            }
                          }

                          final selectedClient = selectedClientDoc.data();
                          final selectedClientName = selectedClient['name']?.toString() ?? 'Cliente';
                          final selectedClientEmail = (selectedClient['email'] ?? '').toString().toLowerCase();

                          return Column(
                            children: [
                              ClientProgress(
                                gymId: widget.gymId,
                                clientName: selectedClientName,
                                clientEmail: selectedClientEmail,
                              ),
                              const SizedBox(height: 16),
                              BodyMeasurementsPanel(
                                gymId: widget.gymId,
                                filterField: 'userEmail',
                                filterValue: selectedClientEmail,
                                title: 'Medidas del cliente',
                                emptyText: 'Este cliente todavía no tiene medidas corporales registradas.',
                              ),
                            ],
                          );
                        },
                      ),
                    if (clients.isNotEmpty && selectedClientId != null)
                      const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: routinesRef.orderBy('createdAt', descending: true).snapshots(),
                      builder: (context, routineSnapshot) {
                        if (routineSnapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final clientNames = {
                          for (final doc in clients) doc.id: doc.data()['name'] ?? 'Sin cliente'
                        };

                        if (selectedClientId == null) {
                          return const AppCard(
                            child: Center(
                              child: Text('Selecciona un cliente para ver sus rutinas y progreso.'),
                            ),
                          );
                        }

                        final routines = (routineSnapshot.data?.docs ?? []).where((doc) {
                          final data = doc.data();

                          if (data['clientId'] != selectedClientId) {
                            return false;
                          }

                          final clientName = (data['clientName'] ?? clientNames[data['clientId']] ?? '').toString();
                          final clientEmail = (data['clientEmail'] ?? '').toString();
                          final fullText = '${data['title'] ?? ''} $clientName $clientEmail'.toLowerCase();
                          return fullText.contains(searchText.toLowerCase());
                        }).toList();

                        if (routines.isEmpty) {
                          return const AppCard(
                            child: Center(
                              child: Text('El cliente seleccionado no tiene rutinas que coincidan con la búsqueda.'),
                            ),
                          );
                        }

                        return Column(
                          children: routines.map((doc) {
                            final data = doc.data();
                            final exercises = List<dynamic>.from(data['exercises'] ?? []);
                            final clientName = (data['clientName'] ?? clientNames[data['clientId']] ?? 'Sin cliente').toString();

                            return RoutineCard(
                              title: data['title'] ?? 'Sin título',
                              day: data['day'] ?? 'Sin día',
                              notes: data['notes'] ?? '',
                              clientName: clientName,
                              exercises: exercises,
                              trainerMode: true,
                              onAddExercise: () => addExercise(doc.id, exercises),
                              onEditRoutine: () => editRoutine(doc.id, data),
                              onDeleteRoutine: () => deleteRoutine(doc.id, data['title'] ?? 'Sin título'),
                              onToggleExercise: (exerciseId, done) => updateExerciseDone(doc.id, exercises, exerciseId, done),
                              onEditExercise: (exerciseId) => editExercise(doc.id, exercises, exerciseId),
                              onDeleteExercise: (exerciseId) => deleteExercise(doc.id, exercises, exerciseId),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

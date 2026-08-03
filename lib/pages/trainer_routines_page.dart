import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/routine_templates.dart';
import '../sheets/exercise_sheet.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/routine_card.dart';
import '../widgets/section_title.dart';
import 'trainer_template_builder_page.dart';

class TrainerRoutinesPage extends StatefulWidget {
  final String gymId;

  const TrainerRoutinesPage({super.key, required this.gymId});

  @override
  State<TrainerRoutinesPage> createState() => _TrainerRoutinesPageState();
}

class _TrainerRoutinesPageState extends State<TrainerRoutinesPage> {
  final routineTitleController = TextEditingController();
  String? selectedClientId;
  String searchText = '';
  String selectedRoutineDay = 'Lunes';
  bool showArchivedRoutines = false;

  CollectionReference<Map<String, dynamic>> get clientsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('clients');

  CollectionReference<Map<String, dynamic>> get routinesRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('routines');


  CollectionReference<Map<String, dynamic>> get customTemplatesRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('routine_templates');


  CollectionReference<Map<String, dynamic>> get activityRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('activity');

  @override
  void dispose() {
    routineTitleController.dispose();
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


  int routineDayOrder(String day) {
    switch (day) {
      case 'Lunes':
        return 1;
      case 'Martes':
        return 2;
      case 'Miércoles':
        return 3;
      case 'Jueves':
        return 4;
      case 'Viernes':
        return 5;
      case 'Sábado':
        return 6;
      case 'Domingo':
        return 7;
      default:
        return 99;
    }
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? selectedClientDocument(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> clients,
  ) {
    if (selectedClientId == null) return null;
    for (final doc in clients) {
      if (doc.id == selectedClientId) return doc;
    }
    return null;
  }

  Future<void> addRoutine(List<QueryDocumentSnapshot<Map<String, dynamic>>> clients) async {
    final title = routineTitleController.text.trim();
    final selectedClientDoc = selectedClientDocument(clients);

    if (title.isEmpty) {
      showSnack('Introduce el nombre de la rutina.');
      return;
    }

    if (selectedClientDoc == null) {
      showSnack('Selecciona un cliente.');
      return;
    }

    final selectedClient = selectedClientDoc.data();
    final actor = await currentActor();
    final routineRef = routinesRef.doc();
    final batch = FirebaseFirestore.instance.batch();

    batch.set(routineRef, {
      'title': title,
      'clientId': selectedClientDoc.id,
      'clientName': selectedClient['name'] ?? 'Sin cliente',
      'clientEmail': (selectedClient['email'] ?? '').toString().toLowerCase(),
      'day': selectedRoutineDay,
      'dayOrder': routineDayOrder(selectedRoutineDay),
      'notes': 'Añade observaciones para el usuario.',
      'exercises': [],
      'status': 'active',
      ...auditCreateFields(actor),
    });

    batch.set(activityRef.doc(), activityFields(
      type: 'routine_created',
      target: title,
      targetId: routineRef.id,
      targetEmail: (selectedClient['email'] ?? '').toString(),
      actor: actor,
      metadata: {'clientName': selectedClient['name'] ?? 'Sin cliente'},
    ));

    await batch.commit();
    routineTitleController.clear();
    showSnack('Rutina creada.');
  }

  Future<void> archiveActiveRoutinesForClient({
    required String clientId,
    required String clientEmail,
    Map<String, String>? actor,
  }) async {
    final normalizedEmail = clientEmail.toLowerCase().trim();
    final existingRoutines = await routinesRef.get();
    final batch = FirebaseFirestore.instance.batch();
    var routinesToArchive = 0;

    for (final routine in existingRoutines.docs) {
      final data = routine.data();
      final routineClientId = data['clientId']?.toString() ?? '';
      final routineClientEmail = (data['clientEmail'] ?? '').toString().toLowerCase().trim();
      final status = (data['status'] ?? 'active').toString();
      final belongsToClient = routineClientId == clientId ||
          (normalizedEmail.isNotEmpty && routineClientEmail == normalizedEmail);

      if (belongsToClient && status != 'archived') {
        routinesToArchive++;
        batch.update(routine.reference, {
          'status': 'archived',
          'archivedAt': FieldValue.serverTimestamp(),
          ...(actor != null ? auditUpdateFields(actor) : {'updatedAt': FieldValue.serverTimestamp()}),
        });
      }
    }

    if (routinesToArchive > 0) {
      await batch.commit();
    }
  }

  String templateDisplayName(Map<String, dynamic> template, String source) {
    final name = template['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final objective = template['objective']?.toString() ?? 'Plantilla';
    final frequency = template['frequency']?.toString() ?? '-';
    final level = template['level']?.toString() ?? '-';
    return source == 'system'
        ? '$objective ${frequency}D · $level'
        : '$objective ${frequency}D · $level personalizada';
  }

  Future<List<Map<String, dynamic>>> loadAutomaticTemplateOptions() async {
    final options = <Map<String, dynamic>>[];

    for (final objective in templateObjectives()) {
      for (final frequency in templateFrequenciesForObjective(objective)) {
        for (final level in templateLevelsForObjectiveAndFrequency(objective, frequency)) {
          final template = findRoutineTemplate(
            objective: objective,
            frequency: frequency,
            level: level,
          );
          if (template == null) continue;
          options.add({
            'id': 'system_${objective}_${frequency}_$level',
            'source': 'system',
            'name': templateDisplayName(template, 'system'),
            'template': template,
          });
        }
      }
    }

    final customSnapshot = await customTemplatesRef.orderBy('createdAt', descending: true).get();
    for (final doc in customSnapshot.docs) {
      final data = doc.data();
      final days = data['days'];
      if (days is! List || days.isEmpty) continue;
      options.insert(0, {
        'id': doc.id,
        'source': 'custom',
        'name': templateDisplayName(data, 'custom'),
        'template': {...data, 'id': doc.id},
      });
    }

    return options;
  }

  void openTemplateManager() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrainerTemplateBuilderPage(gymId: widget.gymId),
      ),
    );
  }

  Future<void> generateAutomaticRoutine(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> clients,
  ) async {
    final selectedClientDoc = selectedClientDocument(clients);
    if (selectedClientDoc == null) {
      showSnack('Selecciona un cliente.');
      return;
    }

    final options = await loadAutomaticTemplateOptions();
    if (options.isEmpty) {
      showSnack('No hay plantillas disponibles.');
      return;
    }

    var selectedTemplateId = options.first['id'].toString();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedOption = options.firstWhere(
              (option) => option['id'].toString() == selectedTemplateId,
              orElse: () => options.first,
            );
            final selectedTemplate = Map<String, dynamic>.from(selectedOption['template'] as Map);
            final source = selectedOption['source'].toString() == 'custom' ? 'Personalizada' : 'Sistema';
            final days = List<dynamic>.from(selectedTemplate['days'] ?? []);

            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              title: const Text('Generar rutina automática'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedTemplateId,
                      dropdownColor: const Color(0xFF0F172A),
                      decoration: const InputDecoration(
                        labelText: 'Plantilla',
                        border: OutlineInputBorder(),
                      ),
                      items: options.map((option) {
                        final name = option['name'].toString();
                        final optionSource = option['source'].toString() == 'custom' ? 'Personalizada' : 'Sistema';
                        return DropdownMenuItem(
                          value: option['id'].toString(),
                          child: Text('$name · $optionSource'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedTemplateId = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$source · ${days.length} días · ${selectedTemplate['level'] ?? 'Sin nivel'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Al generar, se archivarán las rutinas activas anteriores del cliente y se crearán nuevas rutinas desde esta plantilla.',
                      style: TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        openTemplateManager();
                      },
                      icon: const Icon(Icons.tune),
                      label: const Text('Gestionar plantillas'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final option = options.firstWhere(
                      (item) => item['id'].toString() == selectedTemplateId,
                      orElse: () => options.first,
                    );
                    Navigator.pop(dialogContext, option);
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    final template = Map<String, dynamic>.from(result['template'] as Map);
    final daysRaw = template['days'];
    if (daysRaw is! List || daysRaw.isEmpty) {
      showSnack('La plantilla seleccionada no tiene días configurados.');
      return;
    }

    final selectedClient = selectedClientDoc.data();
    final actor = await currentActor();
    await archiveActiveRoutinesForClient(
      clientId: selectedClientDoc.id,
      clientEmail: (selectedClient['email'] ?? '').toString(),
      actor: actor,
    );

    final days = List<Map<String, dynamic>>.from(
      daysRaw.map((day) => Map<String, dynamic>.from(day as Map)),
    );
    days.sort((a, b) {
      final aOrder = a['dayOrder'] is int ? a['dayOrder'] as int : routineDayOrder((a['day'] ?? '').toString());
      final bOrder = b['dayOrder'] is int ? b['dayOrder'] as int : routineDayOrder((b['day'] ?? '').toString());
      return aOrder.compareTo(bOrder);
    });

    final batch = FirebaseFirestore.instance.batch();
    for (final day in days) {
      final exerciseList = day['exercises'] is List ? List<dynamic>.from(day['exercises'] as List) : <dynamic>[];
      final exercises = exerciseList.map((item) {
        final exercise = Map<String, dynamic>.from(item as Map);
        return {
          'id': DateTime.now().microsecondsSinceEpoch.toString() + (exercise['name'] ?? '').toString(),
          'name': exercise['name'] ?? 'Ejercicio',
          'sets': exercise['sets'] ?? 3,
          'reps': exercise['reps'] ?? '10',
          'weight': exercise['weight'] ?? '',
          'rest': exercise['rest'] ?? '60 s',
          'done': false,
          'completedSets': 0,
        };
      }).toList();

      final docRef = routinesRef.doc();
      batch.set(docRef, {
        'title': day['title'] ?? '${template['name'] ?? 'Rutina automática'} · ${day['day'] ?? 'Sin día'}',
        'clientId': selectedClientDoc.id,
        'clientName': selectedClient['name'] ?? 'Sin cliente',
        'clientEmail': (selectedClient['email'] ?? '').toString().toLowerCase(),
        'day': day['day'] ?? 'Sin día',
        'dayOrder': day['dayOrder'] ?? routineDayOrder((day['day'] ?? '').toString()),
        'notes': day['notes'] ?? 'Rutina generada automáticamente desde plantilla.',
        'exercises': exercises,
        'generated': true,
        'generatedTemplateName': template['name'] ?? templateDisplayName(template, result['source'].toString()),
        'generatedTemplateSource': result['source'],
        'generatedObjective': template['objective'],
        'generatedFrequency': template['frequency'],
        'generatedLevel': template['level'],
        'status': 'active',
        ...auditCreateFields(actor),
      });
    }

    batch.set(activityRef.doc(), activityFields(
      type: 'routine_generated',
      target: template['name']?.toString() ?? 'Rutina automática',
      targetId: selectedClientDoc.id,
      targetEmail: (selectedClient['email'] ?? '').toString(),
      actor: actor,
      metadata: {
        'clientName': selectedClient['name'] ?? 'Sin cliente',
        'templateSource': result['source'],
        'objective': template['objective'],
        'frequency': template['frequency'],
        'level': template['level'],
        'days': days.length,
      },
    ));

    await batch.commit();
    showSnack('Rutina automática generada para ${selectedClient['name'] ?? 'el cliente'}.');
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
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
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

    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(routinesRef.doc(routineId), {
      'title': result['title'],
      'day': result['day'],
      'dayOrder': routineDayOrder(result['day'] ?? 'Sin día'),
      'notes': result['notes'],
      ...auditUpdateFields(actor),
    });
    batch.set(activityRef.doc(), activityFields(
      type: 'routine_updated',
      target: result['title'] ?? routineData['title']?.toString() ?? 'Rutina',
      targetId: routineId,
      targetEmail: routineData['clientEmail']?.toString(),
      actor: actor,
      metadata: {
        'clientName': routineData['clientName'] ?? '',
        'previousTitle': routineData['title'] ?? '',
      },
    ));
    await batch.commit();
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
    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(routinesRef.doc(routineId));
    batch.set(activityRef.doc(), activityFields(
      type: 'routine_deleted',
      target: routineTitle,
      targetId: routineId,
      actor: actor,
    ));
    await batch.commit();
    showSnack('Rutina eliminada.');
  }

  Future<void> addExercise(String routineId, List<dynamic> currentExercises) async {
    final result = await showExerciseSheet(context, gymId: widget.gymId);
    if (result == null) return;

    final actor = await currentActor();
    final newExercise = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': result.name,
      'sets': result.sets,
      'reps': result.reps,
      'weight': result.weight,
      'rest': result.rest,
      'done': false,
    };

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final routineRef = routinesRef.doc(routineId);
      final routineSnapshot = await transaction.get(routineRef);
      final routineData = routineSnapshot.data() ?? {};
      transaction.update(routineRef, {
        'exercises': [...currentExercises, newExercise],
        ...auditUpdateFields(actor),
      });
      transaction.set(activityRef.doc(), activityFields(
        type: 'routine_exercise_added',
        target: result.name,
        targetId: routineId,
        targetEmail: routineData['clientEmail']?.toString(),
        actor: actor,
        metadata: {
          'routineTitle': routineData['title'] ?? '',
          'clientName': routineData['clientName'] ?? '',
        },
      ));
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

    final result = await showExerciseSheet(context, gymId: widget.gymId, initialExercise: currentExercise);
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

    final actor = await currentActor();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final routineRef = routinesRef.doc(routineId);
      final routineSnapshot = await transaction.get(routineRef);
      final routineData = routineSnapshot.data() ?? {};
      transaction.update(routineRef, {
        'exercises': updated,
        ...auditUpdateFields(actor),
      });
      transaction.set(activityRef.doc(), activityFields(
        type: 'routine_exercise_updated',
        target: result.name,
        targetId: routineId,
        targetEmail: routineData['clientEmail']?.toString(),
        actor: actor,
        metadata: {
          'routineTitle': routineData['title'] ?? '',
          'clientName': routineData['clientName'] ?? '',
        },
      ));
    });

    showSnack('Ejercicio actualizado.');
  }

  Future<void> updateExerciseDone(String routineId, List<dynamic> exercises, String exerciseId, bool done) async {
    final updated = exercises.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id'] == exerciseId) map['done'] = done;
      return map;
    }).toList();

    final actor = await currentActor();
    await routinesRef.doc(routineId).update({
      'exercises': updated,
      ...auditUpdateFields(actor),
    });
  }

  Future<void> deleteExercise(String routineId, List<dynamic> exercises, String exerciseId) async {
    String deletedExerciseName = exerciseId;
    final updated = exercises.where((item) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id'] == exerciseId) deletedExerciseName = map['name']?.toString() ?? exerciseId;
      return map['id'] != exerciseId;
    }).toList();

    final actor = await currentActor();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final routineRef = routinesRef.doc(routineId);
      final routineSnapshot = await transaction.get(routineRef);
      final routineData = routineSnapshot.data() ?? {};
      transaction.update(routineRef, {
        'exercises': updated,
        ...auditUpdateFields(actor),
      });
      transaction.set(activityRef.doc(), activityFields(
        type: 'routine_exercise_deleted',
        target: deletedExerciseName,
        targetId: routineId,
        targetEmail: routineData['clientEmail']?.toString(),
        actor: actor,
        metadata: {
          'routineTitle': routineData['title'] ?? '',
          'clientName': routineData['clientName'] ?? '',
        },
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    final pagePadding = isCompact ? 12.0 : 16.0;
    final sectionGap = isCompact ? 10.0 : 16.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Rutinas')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: clientsRef.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, clientSnapshot) {
            final clients = clientSnapshot.data?.docs ?? [];
            if (selectedClientId == null && clients.isNotEmpty) {
              selectedClientId = clients.first.id;
            }
            final clientNames = {for (final doc in clients) doc.id: doc.data()['name'] ?? 'Sin cliente'};

            return ListView(
              padding: EdgeInsets.all(pagePadding),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_search, color: Colors.greenAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Cliente',
                            style: TextStyle(fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      SizedBox(height: isCompact ? 8 : 12),
                      if (clients.isEmpty)
                        const Text('Primero crea un cliente.', style: TextStyle(color: Colors.white70))
                      else
                        DropdownButtonFormField<String>(
                          value: selectedClientId,
                          isDense: isCompact,
                          dropdownColor: const Color(0xFF0F172A),
                          decoration: InputDecoration(
                            labelText: 'Cliente seleccionado',
                            border: const OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: isCompact ? 10 : 14,
                            ),
                          ),
                          items: clients.map((doc) {
                            final data = doc.data();
                            final name = data['name'] ?? 'Sin nombre';
                            final email = data['email'] ?? 'Sin email';
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Text(
                                isCompact ? name.toString() : '$name · $email',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => selectedClientId = value),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.greenAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rutinas automáticas',
                              style: TextStyle(fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      if (!isCompact) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'A partir de ahora las rutinas se crean desde plantillas. Configura tus plantillas y luego genera la rutina para el cliente seleccionado.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                      SizedBox(height: isCompact ? 10 : 12),
                      if (isCompact)
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: clients.isEmpty ? null : () => generateAutomaticRoutine(clients),
                                icon: const Icon(Icons.auto_awesome, size: 18),
                                label: const Text('Generar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: openTemplateManager,
                                icon: const Icon(Icons.tune, size: 18),
                                label: const Text('Plantillas'),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: clients.isEmpty ? null : () => generateAutomaticRoutine(clients),
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Generar rutina automática'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: openTemplateManager,
                            icon: const Icon(Icons.tune),
                            label: const Text('Gestionar plantillas automáticas'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) => setState(() => searchText = value),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Buscar rutina',
                          isDense: isCompact,
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: isCompact ? 10 : 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isCompact ? 8 : 16),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 10 : 0,
                    vertical: isCompact ? 6 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: isCompact ? const Color(0xFF0F172A) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile(
                    dense: isCompact,
                    value: showArchivedRoutines,
                    onChanged: (value) => setState(() => showArchivedRoutines = value),
                    title: Text(
                      'Mostrar archivadas',
                      style: TextStyle(fontSize: isCompact ? 14 : 16, fontWeight: FontWeight.w700),
                    ),
                    subtitle: isCompact
                        ? null
                        : const Text(
                            'Por defecto solo se muestran rutinas activas.',
                            style: TextStyle(color: Colors.white60),
                          ),
                    activeColor: Colors.greenAccent,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(height: isCompact ? 8 : 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: routinesRef.orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, routineSnapshot) {
                    if (routineSnapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (selectedClientId == null) {
                      return const AppCard(child: Text('Selecciona un cliente para ver sus rutinas.'));
                    }
                    final routines = (routineSnapshot.data?.docs ?? []).where((doc) {
                      final data = doc.data();
                      if (data['clientId'] != selectedClientId) return false;
                      final status = (data['status'] ?? 'active').toString();
                      if (!showArchivedRoutines && status == 'archived') return false;
                      final clientName = (data['clientName'] ?? clientNames[data['clientId']] ?? '').toString();
                      final clientEmail = (data['clientEmail'] ?? '').toString();
                      final fullText = '${data['title'] ?? ''} $clientName $clientEmail'.toLowerCase();
                      return fullText.contains(searchText.toLowerCase());
                    }).toList();
                    routines.sort((a, b) {
                      final aOrder = a.data()['dayOrder'] is int
                          ? a.data()['dayOrder'] as int
                          : routineDayOrder((a.data()['day'] ?? '').toString());
                      final bOrder = b.data()['dayOrder'] is int
                          ? b.data()['dayOrder'] as int
                          : routineDayOrder((b.data()['day'] ?? '').toString());
                      final orderCompare = aOrder.compareTo(bOrder);
                      if (orderCompare != 0) return orderCompare;
                      return (a.data()['title'] ?? '').toString().compareTo((b.data()['title'] ?? '').toString());
                    });
                    if (routines.isEmpty) {
                      return const AppCard(child: Text('El cliente seleccionado no tiene rutinas que coincidan con la búsqueda.'));
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
                          archived: (data['status'] ?? 'active').toString() == 'archived',
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
      ),
    );
  }

}
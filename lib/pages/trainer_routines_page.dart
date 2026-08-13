import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../services/trainer_routine_service.dart';
import '../sheets/exercise_sheet.dart';
import '../utils/workout_utils.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/routine_card.dart';
import 'routine_comments_page.dart';
import 'trainer_template_builder_page.dart';

class TrainerRoutinesPage extends StatefulWidget {
  final String gymId;
  final String? initialClientId;
  final String? initialClientName;
  final bool focusCreation;
  const TrainerRoutinesPage({super.key, required this.gymId, this.initialClientId, this.initialClientName, this.focusCreation = false});

  @override
  State<TrainerRoutinesPage> createState() => _TrainerRoutinesPageState();
}

class _TrainerRoutinesPageState extends State<TrainerRoutinesPage> {
  String? selectedClientId;

  @override
  void initState() {
    super.initState();
    selectedClientId = widget.initialClientId;
  }
  String searchText = '';
  bool showArchivedRoutines = false;
  bool weeklyCheckRunning = false;
  final Set<String> weeklyCheckedClientIds = <String>{};

  TrainerRoutineService get routineService => TrainerRoutineService(gymId: widget.gymId);

  void showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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

  void openTemplateManager() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrainerTemplateBuilderPage(gymId: widget.gymId)),
    );
  }

  Future<void> prepareCurrentWeek(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> clients, {
    bool manual = false,
  }) async {
    if (weeklyCheckRunning) return;
    final selectedClientDoc = selectedClientDocument(clients);
    if (selectedClientDoc == null) {
      if (manual) showSnack('Selecciona un cliente.');
      return;
    }
    if (!manual && weeklyCheckedClientIds.contains(selectedClientDoc.id)) return;
    weeklyCheckedClientIds.add(selectedClientDoc.id);
    weeklyCheckRunning = true;
    try {
      final message = await routineService.prepareCurrentWeekForClient(
        clientId: selectedClientDoc.id,
        clientData: selectedClientDoc.data(),
      );
      if (!mounted) return;
      if (manual || message.startsWith('Semana creada')) showSnack(message);
    } catch (error) {
      if (manual) showSnack('No se ha podido preparar la semana: $error');
    } finally {
      weeklyCheckRunning = false;
    }
  }

  Future<void> generateAutomaticRoutine(List<QueryDocumentSnapshot<Map<String, dynamic>>> clients) async {
    final selectedClientDoc = selectedClientDocument(clients);
    if (selectedClientDoc == null) {
      showSnack('Selecciona un cliente.');
      return;
    }

    final options = await routineService.loadAutomaticTemplateOptions();
    if (!mounted) return;

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
            return AlertDialog(
              backgroundColor: context.gymSurface,
              title: Text('Generar rutina automÃ¡tica'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedTemplateId,
                    dropdownColor: context.gymSurface,
                    decoration: InputDecoration(labelText: 'Plantilla', border: OutlineInputBorder()),
                    items: options.map((option) {
                      final name = option['name'].toString();
                      final source = option['source'].toString() == 'custom' ? 'Personalizada' : 'Sistema';
                      return DropdownMenuItem(value: option['id'].toString(), child: Text('$name Â· $source'));
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedTemplateId = value);
                    },
                  ),
                  SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      openTemplateManager();
                    },
                    icon: Icon(Icons.tune),
                    label: Text('Gestionar plantillas'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancelar')),
                FilledButton.icon(
                  onPressed: () {
                    final option = options.firstWhere(
                      (item) => item['id'].toString() == selectedTemplateId,
                      orElse: () => options.first,
                    );
                    Navigator.pop(dialogContext, option);
                  },
                  icon: Icon(Icons.auto_awesome),
                  label: Text('Generar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    try {
      final message = await routineService.generateAutomaticRoutine(
        clientId: selectedClientDoc.id,
        clientData: selectedClientDoc.data(),
        selectedOption: result,
      );
      showSnack(message);
    } on StateError catch (error) {
      showSnack(error.message);
    }
  }

  Future<Map<String, String>?> showRoutineEditorDialog(Map<String, dynamic> routineData) async {
    final titleController = TextEditingController(text: routineData['title']?.toString() ?? '');
    final dayController = TextEditingController(text: routineData['day']?.toString() ?? '');
    final notesController = TextEditingController(text: routineData['notes']?.toString() ?? '');

    try {
      return await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: context.gymSurface,
            title: Text('Editar rutina'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(controller: titleController, label: 'Nombre de la rutina'),
                SizedBox(height: 12),
                AppTextField(controller: dayController, label: 'DÃ­a'),
                SizedBox(height: 12),
                AppTextField(controller: notesController, label: 'Notas'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancelar')),
              FilledButton.icon(
                onPressed: () {
                  final title = titleController.text.trim();
                  if (title.isEmpty) return;
                  Navigator.pop(dialogContext, {
                    'title': title,
                    'day': dayController.text.trim().isEmpty ? 'Sin dÃ­a' : dayController.text.trim(),
                    'notes': notesController.text.trim(),
                  });
                },
                icon: Icon(Icons.save),
                label: Text('Guardar'),
              ),
            ],
          );
        },
      );
    } finally {
      titleController.dispose();
      dayController.dispose();
      notesController.dispose();
    }
  }

  Future<void> editRoutine(String routineId, Map<String, dynamic> routineData) async {
    final result = await showRoutineEditorDialog(routineData);
    if (result == null) return;

    await routineService.updateRoutine(
      routineId: routineId,
      routineData: routineData,
      title: result['title'] ?? 'Rutina',
      day: result['day'] ?? 'Sin dÃ­a',
      notes: result['notes'] ?? '',
    );
    showSnack('Rutina actualizada.');
  }

  Future<void> deleteRoutine(String routineId, String routineTitle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.gymSurface,
          title: Text('Eliminar rutina'),
          content: Text('Â¿Seguro que quieres eliminar la rutina "$routineTitle"? Esta acciÃ³n no se puede deshacer.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('Cancelar')),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: Icon(Icons.delete_outline),
              label: Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    await routineService.deleteRoutine(routineId: routineId, routineTitle: routineTitle);
    showSnack('Rutina eliminada.');
  }

  Future<void> addExercise(String routineId, List<dynamic> currentExercises) async {
    final result = await showExerciseSheet(context, gymId: widget.gymId);
    if (result == null) return;
    await routineService.addExercise(routineId: routineId, currentExercises: currentExercises, input: result);
  }

  Future<void> editExercise(String routineId, List<dynamic> exercises, String exerciseId) async {
    Map<String, dynamic>? currentExercise;
    for (final item in exercises) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id'] == exerciseId) currentExercise = map;
    }
    if (currentExercise == null) {
      showSnack('No se ha encontrado el ejercicio.');
      return;
    }

    final result = await showExerciseSheet(context, gymId: widget.gymId, initialExercise: currentExercise);
    if (result == null) return;
    await routineService.editExercise(routineId: routineId, exercises: exercises, exerciseId: exerciseId, input: result);
    showSnack('Ejercicio actualizado.');
  }

  Future<void> updateExerciseDone(String routineId, List<dynamic> exercises, String exerciseId, bool done) async {
    await routineService.updateExerciseDone(routineId: routineId, exercises: exercises, exerciseId: exerciseId, done: done);
  }

  Future<void> deleteExercise(String routineId, List<dynamic> exercises, String exerciseId) async {
    await routineService.deleteExercise(routineId: routineId, exercises: exercises, exerciseId: exerciseId);
  }

  @override
  Widget build(BuildContext context) {
    final service = routineService;
    final isCompact = MediaQuery.of(context).size.width < 600;
    final pagePadding = isCompact ? 12.0 : 16.0;
    final sectionGap = isCompact ? 10.0 : 16.0;

    return Scaffold(
      appBar: AppBar(title: Text('Rutinas')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: service.clientsRef.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, clientSnapshot) {
            final clients = clientSnapshot.data?.docs ?? [];
            if (selectedClientId != null && clients.isNotEmpty && !clients.any((doc) => doc.id == selectedClientId)) selectedClientId = clients.first.id;
            if (selectedClientId == null && clients.isNotEmpty) selectedClientId = clients.first.id;
            if (selectedClientId != null && clients.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) => prepareCurrentWeek(clients));
            }
            final clientNames = {for (final doc in clients) doc.id: doc.data()['name'] ?? 'Sin cliente'};

            return ListView(
              padding: EdgeInsets.all(pagePadding),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.focusCreation && widget.initialClientName != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: context.gymFitnessAccent.withValues(alpha: 0.22))),
                          child: Row(children: [
                            Icon(Icons.auto_awesome, color: context.gymPrimary, size: 18),
                            SizedBox(width: 8),
                            Expanded(child: Text('Asignando rutina a: ', style: TextStyle(fontWeight: FontWeight.w900, color: context.gymText))),
                          ]),
                        ),
                      ],
                      Row(
                        children: [
                          Icon(Icons.person_search, color: context.gymPrimary, size: 20),
                          SizedBox(width: 8),
                          Text('Cliente', style: TextStyle(fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      SizedBox(height: isCompact ? 8 : 12),
                      if (clients.isEmpty)
                        Text('Primero crea un cliente.', style: TextStyle(color: context.gymMutedText))
                      else
                        DropdownButtonFormField<String>(
                          initialValue: selectedClientId,
                          isDense: isCompact,
                          dropdownColor: context.gymSurface,
                          decoration: InputDecoration(
                            labelText: 'Cliente seleccionado',
                            border: const OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isCompact ? 10 : 14),
                          ),
                          items: clients.map((doc) {
                            final data = doc.data();
                            final name = data['name'] ?? 'Sin nombre';
                            final email = data['email'] ?? 'Sin email';
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Text(isCompact ? name.toString() : '$name Â· $email', overflow: TextOverflow.ellipsis),
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
                          Icon(Icons.auto_awesome, color: context.gymFitnessAccent, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('Rutinas automÃ¡ticas', style: TextStyle(fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      SizedBox(height: isCompact ? 10 : 12),
                      if (isCompact) ...[
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: clients.isEmpty ? null : () => generateAutomaticRoutine(clients),
                                icon: Icon(Icons.auto_awesome, size: 18),
                                label: Text('Generar'),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(onPressed: openTemplateManager, icon: Icon(Icons.tune, size: 18), label: Text('Plantillas')),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: clients.isEmpty ? null : () => prepareCurrentWeek(clients, manual: true),
                            icon: Icon(Icons.calendar_month, size: 18),
                            label: Text('Preparar semana'),
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: clients.isEmpty ? null : () => generateAutomaticRoutine(clients),
                            icon: Icon(Icons.auto_awesome),
                            label: Text('Generar rutina automÃ¡tica'),
                          ),
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(onPressed: openTemplateManager, icon: Icon(Icons.tune), label: Text('Gestionar plantillas automÃ¡ticas')),
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: clients.isEmpty ? null : () => prepareCurrentWeek(clients, manual: true),
                            icon: Icon(Icons.calendar_month),
                            label: Text('Preparar semana actual'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                TextField(
                  onChanged: (value) => setState(() => searchText = value),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar rutina',
                    isDense: isCompact,
                    filled: true,
                    fillColor: context.gymSurface,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isCompact ? 10 : 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  ),
                ),
                SizedBox(height: isCompact ? 8 : 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 0, vertical: isCompact ? 6 : 0),
                  decoration: BoxDecoration(color: isCompact ? context.gymSubtleSurface : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                  child: SwitchListTile(
                    dense: isCompact,
                    value: showArchivedRoutines,
                    onChanged: (value) => setState(() => showArchivedRoutines = value),
                    title: Text('Mostrar archivadas', style: TextStyle(fontSize: isCompact ? 14 : 16, fontWeight: FontWeight.w700)),
                    subtitle: isCompact ? null : Text('Por defecto solo se muestran rutinas activas.', style: TextStyle(color: context.gymMutedText)),
                    activeThumbColor: context.gymPrimary,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: selectedClientId == null ? null : service.routinesRef.where('clientId', isEqualTo: selectedClientId).snapshots(),
                  builder: (context, routineSnapshot) {
                    if (routineSnapshot.connectionState == ConnectionState.waiting) {
                      return Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                    }
                    if (selectedClientId == null) return AppCard(child: Text('Selecciona un cliente para ver sus rutinas.'));

                    final routines = (routineSnapshot.data?.docs ?? []).where((doc) {
                      final data = doc.data();
                      final status = (data['status'] ?? 'active').toString();
                      if (!showArchivedRoutines && status == 'archived') return false;
                      final clientName = (data['clientName'] ?? clientNames[data['clientId']] ?? '').toString();
                      final clientEmail = (data['clientEmail'] ?? '').toString();
                      final fullText = '${data['title'] ?? ''} $clientName $clientEmail'.toLowerCase();
                      return fullText.contains(searchText.toLowerCase());
                    }).toList();

                    routines.sort((a, b) {
                      final aOrder = a.data()['dayOrder'] is int ? a.data()['dayOrder'] as int : routineDayOrder((a.data()['day'] ?? '').toString());
                      final bOrder = b.data()['dayOrder'] is int ? b.data()['dayOrder'] as int : routineDayOrder((b.data()['day'] ?? '').toString());
                      final orderCompare = aOrder.compareTo(bOrder);
                      if (orderCompare != 0) return orderCompare;
                      return (a.data()['title'] ?? '').toString().compareTo((b.data()['title'] ?? '').toString());
                    });

                    if (routines.isEmpty) return AppCard(child: Text('El cliente seleccionado no tiene rutinas que coincidan con la bÃºsqueda.'));

                    return Column(
                      children: routines.map((doc) {
                        final data = doc.data();
                        final exercises = List<dynamic>.from(data['exercises'] ?? []);
                        final clientName = (data['clientName'] ?? clientNames[data['clientId']] ?? 'Sin cliente').toString();
                        final routineTitle = data['title'] ?? 'Sin tÃ­tulo';

                        return RoutineCard(
                          title: routineTitle,
                          day: data['day'] ?? 'Sin dÃ­a',
                          notes: data['notes'] ?? '',
                          clientName: clientName,
                          exercises: exercises,
                          trainerMode: true,
                          archived: (data['status'] ?? 'active').toString() == 'archived',
                          commentsCount: workoutIntValue(data['commentsCount']),
                          onOpenComments: () async {
                            final navigator = Navigator.of(context);
                            final actor = await service.currentActor();
                            if (!mounted) return;
                            navigator.push(
                              MaterialPageRoute(
                                builder: (_) => RoutineCommentsPage(
                                  gymId: widget.gymId,
                                  routineId: doc.id,
                                  routineTitle: routineTitle,
                                  currentUserId: actor['uid'] ?? '',
                                  currentUserName: actor['name'] ?? 'Entrenador',
                                  currentUserEmail: actor['email'] ?? '',
                                  currentUserRole: 'trainer',
                                ),
                              ),
                            );
                          },
                          onAddExercise: () => addExercise(doc.id, exercises),
                          onEditRoutine: () => editRoutine(doc.id, data),
                          onDeleteRoutine: () => deleteRoutine(doc.id, routineTitle),
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





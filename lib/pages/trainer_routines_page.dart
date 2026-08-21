import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/navigation_service.dart';
import '../services/trainer_routine_service.dart';
import '../sheets/exercise_sheet.dart';
import '../utils/workout_utils.dart';
import '../widgets/app_text_field.dart';
import '../widgets/routine_card.dart';
import 'routine_comments_page.dart';
import 'trainer_template_builder_page.dart';

class TrainerRoutinesPage extends StatefulWidget {
  final String gymId;
  final String? initialClientId;
  final String? initialClientName;
  final bool focusCreation;
  const TrainerRoutinesPage({
    super.key,
    required this.gymId,
    this.initialClientId,
    this.initialClientName,
    this.focusCreation = false,
  });
  @override
  State<TrainerRoutinesPage> createState() => _TrainerRoutinesPageState();
}

class _TrainerRoutinesPageState extends State<TrainerRoutinesPage> {
  String? selectedClientId;
  String searchText = '';
  bool showArchivedRoutines = false;
  bool weeklyCheckRunning = false;
  bool _initialDayScrollDone = false;
  final Set<String> weeklyCheckedClientIds = <String>{};
  TrainerRoutineService get routineService => TrainerRoutineService(gymId: widget.gymId);

  @override
  void initState() {
    super.initState();
    selectedClientId = widget.initialClientId;
  }

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

  int dayOrderForRoutine(QueryDocumentSnapshot<Map<String, dynamic>> routine) {
    final data = routine.data();
    if (data['dayOrder'] is int) return data['dayOrder'] as int;
    return routineDayOrder((data['day'] ?? '').toString());
  }

  String? targetRoutineIdForToday(List<QueryDocumentSnapshot<Map<String, dynamic>>> routines) {
    if (routines.isEmpty) return null;
    final todayOrder = DateTime.now().weekday;
    final sorted = sortRoutines(routines);
    for (final routine in sorted) {
      final order = dayOrderForRoutine(routine);
      if (order >= todayOrder) return routine.id;
    }
    return sorted.first.id;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> sortRoutines(List<QueryDocumentSnapshot<Map<String, dynamic>>> routines) {
    final sorted = [...routines];
    sorted.sort((a, b) {
      final aOrder = a.data()['dayOrder'] is int ? a.data()['dayOrder'] as int : routineDayOrder((a.data()['day'] ?? '').toString());
      final bOrder = b.data()['dayOrder'] is int ? b.data()['dayOrder'] as int : routineDayOrder((b.data()['day'] ?? '').toString());
      final orderCompare = aOrder.compareTo(bOrder);
      if (orderCompare != 0) return orderCompare;
      return (a.data()['title'] ?? '').toString().compareTo((b.data()['title'] ?? '').toString());
    });
    return sorted;
  }

  void openTemplateManager() {
    AppNavigation.push(
      context,
      TrainerTemplateBuilderPage(gymId: widget.gymId),
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
              title: const Text('Generar rutina automática'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedTemplateId,
                    dropdownColor: context.gymSurface,
                    decoration: const InputDecoration(labelText: 'Plantilla', border: OutlineInputBorder()),
                    items: options.map((option) {
                      final name = option['name'].toString();
                      final source = option['source'].toString() == 'custom' ? 'Personalizada' : 'Sistema';
                      return DropdownMenuItem(value: option['id'].toString(), child: Text('$name · $source'));
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedTemplateId = value);
                    },
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
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
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
                  if (title.isEmpty) return;
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
      day: result['day'] ?? 'Sin día',
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
    return Scaffold(
      appBar: AppBar(title: const Text('Rutinas')),
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
            final selectedClientName = selectedClientId == null ? 'Sin cliente' : (clientNames[selectedClientId] ?? 'Cliente');
            return ListView(
              padding: EdgeInsets.fromLTRB(pagePadding, pagePadding, pagePadding, 92),
              children: [
                _TrainerRoutinesHero(clientName: selectedClientName.toString(), clientsCount: clients.length),
                const SizedBox(height: 12),
                _ClientSelectorPanel(
                  clients: clients,
                  selectedClientId: selectedClientId,
                  isCompact: isCompact,
                  onChanged: (value) => setState(() {
                    selectedClientId = value;
                    _initialDayScrollDone = false;
                  }),
                ),
                const SizedBox(height: 12),
                _RoutineQuickActions(
                  hasClients: clients.isNotEmpty,
                  onGenerate: () => generateAutomaticRoutine(clients),
                  onTemplates: openTemplateManager,
                  onPrepareWeek: () => prepareCurrentWeek(clients, manual: true),
                ),
                const SizedBox(height: 12),
                _TrainerSearchField(
                  hint: 'Buscar rutina',
                  onChanged: (value) => setState(() {
                    searchText = value;
                    _initialDayScrollDone = false;
                  }),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  dense: true,
                  value: showArchivedRoutines,
                  onChanged: (value) => setState(() {
                    showArchivedRoutines = value;
                    _initialDayScrollDone = false;
                  }),
                  title: Text('Mostrar archivadas', style: TextStyle(color: context.gymText, fontWeight: FontWeight.w800)),
                  activeThumbColor: context.gymPrimary,
                  contentPadding: EdgeInsets.zero,
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: selectedClientId == null ? null : service.routinesRef.where('clientId', isEqualTo: selectedClientId).snapshots(),
                  builder: (context, routineSnapshot) {
                    if (routineSnapshot.connectionState == ConnectionState.waiting) {
                      return Padding(padding: const EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: context.gymPrimary)));
                    }
                    if (selectedClientId == null) return _TrainerEmptyState(icon: Icons.person_search_rounded, title: 'Selecciona un cliente', subtitle: 'Elige un cliente para ver o crear rutinas.');
                    final routines = (routineSnapshot.data?.docs ?? []).where((doc) {
                      final data = doc.data();
                      final status = (data['status'] ?? 'active').toString();
                      if (!showArchivedRoutines && status == 'archived') return false;
                      final clientName = (data['clientName'] ?? clientNames[data['clientId']] ?? '').toString();
                      final clientEmail = (data['clientEmail'] ?? '').toString();
                      final fullText = '${data['title'] ?? ''} $clientName $clientEmail'.toLowerCase();
                      return fullText.contains(searchText.toLowerCase());
                    }).toList();
                    final sortedRoutines = sortRoutines(routines);
                    if (sortedRoutines.isEmpty) return _TrainerEmptyState(icon: Icons.fitness_center_rounded, title: 'Sin rutinas visibles', subtitle: 'El cliente seleccionado no tiene rutinas que coincidan con la búsqueda.');
                    final targetRoutineId = _initialDayScrollDone ? null : targetRoutineIdForToday(sortedRoutines);
                    return _TrainerRoutineList(
                      gymId: widget.gymId,
                      routines: sortedRoutines,
                      clientNames: clientNames,
                      service: service,
                      targetRoutineId: targetRoutineId,
                      onInitialScrollComplete: () {
                        if (mounted && !_initialDayScrollDone) {
                          setState(() => _initialDayScrollDone = true);
                        }
                      },
                      onAddExercise: addExercise,
                      onEditRoutine: editRoutine,
                      onDeleteRoutine: deleteRoutine,
                      onToggleExercise: updateExerciseDone,
                      onEditExercise: editExercise,
                      onDeleteExercise: deleteExercise,
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

class _TrainerRoutineList extends StatelessWidget {
  final String gymId;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> routines;
  final Map<String, Object?> clientNames;
  final TrainerRoutineService service;
  final String? targetRoutineId;
  final VoidCallback onInitialScrollComplete;
  final Future<void> Function(String routineId, List<dynamic> currentExercises) onAddExercise;
  final Future<void> Function(String routineId, Map<String, dynamic> routineData) onEditRoutine;
  final Future<void> Function(String routineId, String routineTitle) onDeleteRoutine;
  final Future<void> Function(String routineId, List<dynamic> exercises, String exerciseId, bool done) onToggleExercise;
  final Future<void> Function(String routineId, List<dynamic> exercises, String exerciseId) onEditExercise;
  final Future<void> Function(String routineId, List<dynamic> exercises, String exerciseId) onDeleteExercise;

  const _TrainerRoutineList({
    required this.gymId,
    required this.routines,
    required this.clientNames,
    required this.service,
    required this.targetRoutineId,
    required this.onInitialScrollComplete,
    required this.onAddExercise,
    required this.onEditRoutine,
    required this.onDeleteRoutine,
    required this.onToggleExercise,
    required this.onEditExercise,
    required this.onDeleteExercise,
  });

  @override
  Widget build(BuildContext context) {
    final targetKey = targetRoutineId == null ? null : GlobalObjectKey('trainer-routine-auto-scroll-$targetRoutineId');
    if (targetKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = targetKey.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(targetContext, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic, alignment: 0.08);
        }
        onInitialScrollComplete();
      });
    }
    return Column(
      children: routines.map((doc) {
        final data = doc.data();
        final exercises = List<dynamic>.from(data['exercises'] ?? []);
        final clientName = (data['clientName'] ?? clientNames[data['clientId']] ?? 'Sin cliente').toString();
        final routineTitle = data['title'] ?? 'Sin título';
        final routineCard = RoutineCard(
          key: ValueKey('trainer-routine-card-${doc.id}'),
          title: routineTitle,
          day: data['day'] ?? 'Sin día',
          notes: data['notes'] ?? '',
          clientName: clientName,
          exercises: exercises,
          trainerMode: true,
          archived: (data['status'] ?? 'active').toString() == 'archived',
          commentsCount: workoutIntValue(data['commentsCount']),
          onOpenComments: () async {
            final actor = await service.currentActor();
            if (!context.mounted) return;
            AppNavigation.push(context, RoutineCommentsPage(gymId: gymId, routineId: doc.id, routineTitle: routineTitle, currentUserId: actor['uid'] ?? '', currentUserName: actor['name'] ?? 'Entrenador', currentUserEmail: actor['email'] ?? '', currentUserRole: 'trainer'));
          },
          onAddExercise: () => onAddExercise(doc.id, exercises),
          onEditRoutine: () => onEditRoutine(doc.id, data),
          onDeleteRoutine: () => onDeleteRoutine(doc.id, routineTitle),
          onToggleExercise: (exerciseId, done) => onToggleExercise(doc.id, exercises, exerciseId, done),
          onEditExercise: (exerciseId) => onEditExercise(doc.id, exercises, exerciseId),
          onDeleteExercise: (exerciseId) => onDeleteExercise(doc.id, exercises, exerciseId),
        );
        if (doc.id == targetRoutineId && targetKey != null) {
          return KeyedSubtree(key: targetKey, child: routineCard);
        }
        return routineCard;
      }).toList(),
    );
  }
}

class _TrainerRoutinesHero extends StatelessWidget {
  final String clientName;
  final int clientsCount;
  const _TrainerRoutinesHero({required this.clientName, required this.clientsCount});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(28)),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(19)), child: Icon(Icons.fitness_center_rounded, color: context.gymPrimary, size: 25)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Rutinas', style: TextStyle(color: context.gymText, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
          const SizedBox(height: 4),
          Text('$clientName · $clientsCount clientes', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ])),
      ]),
    );
  }
}

class _ClientSelectorPanel extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> clients;
  final String? selectedClientId;
  final bool isCompact;
  final ValueChanged<String?> onChanged;
  const _ClientSelectorPanel({required this.clients, required this.selectedClientId, required this.isCompact, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    if (clients.isEmpty) return _TrainerEmptyState(icon: Icons.people_outline_rounded, title: 'Primero crea un cliente', subtitle: 'Necesitas añadir clientes antes de preparar rutinas.');
    return DropdownButtonFormField<String>(
      initialValue: selectedClientId,
      isDense: isCompact,
      dropdownColor: context.gymSurface,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.person_search_rounded),
        labelText: 'Cliente seleccionado',
        filled: true,
        fillColor: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.44 : 0.68),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
      ),
      items: clients.map((doc) {
        final data = doc.data();
        final name = data['name'] ?? 'Sin nombre';
        final email = data['email'] ?? 'Sin email';
        return DropdownMenuItem(value: doc.id, child: Text(isCompact ? name.toString() : '$name · $email', overflow: TextOverflow.ellipsis));
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _RoutineQuickActions extends StatelessWidget {
  final bool hasClients;
  final VoidCallback onGenerate;
  final VoidCallback onTemplates;
  final VoidCallback onPrepareWeek;
  const _RoutineQuickActions({required this.hasClients, required this.onGenerate, required this.onTemplates, required this.onPrepareWeek});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(children: [
        _RoutineActionChip(icon: Icons.auto_awesome_rounded, text: 'Generar', enabled: hasClients, onTap: onGenerate),
        const SizedBox(width: 8),
        _RoutineActionChip(icon: Icons.tune_rounded, text: 'Plantillas', enabled: true, onTap: onTemplates),
        const SizedBox(width: 8),
        _RoutineActionChip(icon: Icons.calendar_month_rounded, text: 'Semana', enabled: hasClients, onTap: onPrepareWeek),
      ]),
    );
  }
}

class _RoutineActionChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool enabled;
  final VoidCallback onTap;
  const _RoutineActionChip({required this.icon, required this.text, required this.enabled, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onTap : null,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.46 : 0.68), borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: enabled ? context.gymPrimary : context.gymMutedText, size: 18), const SizedBox(width: 7), Text(text, style: TextStyle(color: enabled ? context.gymText : context.gymMutedText, fontWeight: FontWeight.w900))]),
        ),
      ),
    );
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
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: hint,
        filled: true,
        fillColor: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.44 : 0.68),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: context.gymPrimary.withValues(alpha: 0.55), width: 1.2)),
      ),
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/workout_log_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';

class RecentWorkoutHistory extends StatefulWidget {
  final CollectionReference<Map<String, dynamic>> logsRef;
  final String userId;

  const RecentWorkoutHistory({
    super.key,
    required this.logsRef,
    required this.userId,
  });

  @override
  State<RecentWorkoutHistory> createState() => _RecentWorkoutHistoryState();
}

class _RecentWorkoutHistoryState extends State<RecentWorkoutHistory> {
  final TextEditingController searchController = TextEditingController();
  String searchText = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get logsRef => widget.logsRef;
  String get userId => widget.userId;

  int timestampSortValue(WorkoutLogModel log) {
    return log.createdAt?.millisecondsSinceEpoch ?? 0;
  }

  List<WorkoutLogModel> filteredLogs(List<WorkoutLogModel> logs) {
    final query = searchText.trim();
    if (query.isEmpty) return logs.take(20).toList();
    return logs.where((log) => log.matchesExerciseQuery(query)).toList();
  }

  double bestWeight(List<WorkoutLogModel> logs) {
    var best = 0.0;
    for (final log in logs) {
      if (log.weight > best) best = log.weight;
    }
    return best;
  }

  int totalReps(List<WorkoutLogModel> logs) {
    var total = 0;
    for (final log in logs) {
      total += log.reps;
    }
    return total;
  }

  String formatWeight(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  Future<void> editWorkoutLog(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final log = WorkoutLogModel.fromDoc(doc);
    final weightController = TextEditingController(text: log.formattedWeight);
    final repsController = TextEditingController(text: log.reps.toString());

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.gymSurface,
          title: const Text('Editar registro'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: weightController,
                label: 'Peso realizado (kg)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: repsController,
                label: 'Repeticiones realizadas',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                final weight = double.tryParse(weightController.text.trim().replaceAll(',', '.'));
                final reps = int.tryParse(repsController.text.trim());

                if (weight == null || reps == null || weight < 0 || reps <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Introduce peso y repeticiones válidas.')),
                  );
                  return;
                }

                Navigator.pop(dialogContext, {'weight': weight, 'reps': reps});
              },
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    weightController.dispose();
    repsController.dispose();

    if (result == null) return;

    await logsRef.doc(doc.id).update({
      'weight': result['weight'],
      'reps': result['reps'],
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro actualizado.')),
      );
    }
  }

  Future<void> deleteWorkoutLog(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final log = WorkoutLogModel.fromDoc(doc);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.gymSurface,
          title: const Text('Eliminar registro'),
          content: Text('¿Seguro que quieres eliminar ${log.exercise}? Esta acción no se puede deshacer.'),
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

    await logsRef.doc(doc.id).delete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro eliminado.')),
      );
    }
  }

  Widget buildSearchBox(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(icon: Icons.search, title: 'Buscar ejercicio'),
          const SizedBox(height: 10),
          TextField(
            controller: searchController,
            onChanged: (value) => setState(() => searchText = value),
            decoration: InputDecoration(
              hintText: 'Ejemplo: press banca, sentadilla, remo...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchText.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        searchController.clear();
                        setState(() => searchText = '');
                      },
                    ),
              filled: true,
              fillColor: context.gymSubtleSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: context.gymBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: context.gymBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: context.gymPrimary, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Busca por nombre de ejercicio para comparar pesos y repeticiones de otros días.',
            style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget buildSearchSummary(BuildContext context, List<WorkoutLogModel> logs) {
    if (searchText.trim().isEmpty || logs.isEmpty) return const SizedBox.shrink();

    final best = bestWeight(logs);
    final reps = totalReps(logs);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            InfoChip(text: '${logs.length} registros'),
            InfoChip(text: 'Mejor peso: ${formatWeight(best)} kg'),
            InfoChip(text: '$reps reps totales'),
          ],
        ),
      ),
    );
  }

  Widget buildWorkoutLogTile(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final log = WorkoutLogModel.fromDoc(doc);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.gymBorder),
      ),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: context.gymPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.monitor_weight, color: context.gymPrimary),
        ),
        title: Text(
          log.exercise,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(log.routineTitle, style: TextStyle(color: context.gymMutedText)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  InfoChip(text: '${log.formattedWeight} kg'),
                  InfoChip(text: '${log.reps} reps'),
                  InfoChip(text: log.setText),
                  InfoChip(text: log.formattedDate),
                ],
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Editar registro',
              onPressed: () => editWorkoutLog(context, doc),
              icon: Icon(Icons.edit, color: context.gymPrimary),
            ),
            IconButton(
              tooltip: 'Eliminar registro',
              onPressed: () => deleteWorkoutLog(context, doc),
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSearchBox(context),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: logsRef.where('userId', isEqualTo: userId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AppCard(
                child: Center(child: CircularProgressIndicator(color: context.gymPrimary)),
              );
            }

            final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
              ...(snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]),
            ];

            final logs = docs.map(WorkoutLogModel.fromDoc).toList()
              ..sort((a, b) => timestampSortValue(b).compareTo(timestampSortValue(a)));

            final visibleLogs = filteredLogs(logs);
            final visibleIds = visibleLogs.map((log) => log.id).toSet();
            final visibleDocs = docs.where((doc) => visibleIds.contains(doc.id)).toList()
              ..sort((a, b) {
                final aLog = WorkoutLogModel.fromDoc(a);
                final bLog = WorkoutLogModel.fromDoc(b);
                return timestampSortValue(bLog).compareTo(timestampSortValue(aLog));
              });
            final isSearching = searchText.trim().isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildSearchSummary(context, visibleLogs),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(
                        icon: isSearching ? Icons.manage_search : Icons.history,
                        title: isSearching ? 'Resultados de búsqueda' : 'Historial reciente',
                      ),
                      const SizedBox(height: 12),
                      if (visibleDocs.isEmpty)
                        Text(
                          isSearching
                              ? 'No hay registros para "$searchText". Prueba con otro nombre de ejercicio.'
                              : 'Todavía no hay entrenamientos registrados.',
                          style: TextStyle(color: context.gymMutedText),
                        )
                      else
                        ...visibleDocs.map((doc) => buildWorkoutLogTile(context, doc)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

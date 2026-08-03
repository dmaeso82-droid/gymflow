
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';
import 'weekly_summary.dart';

class ClientProgress extends StatelessWidget {
  final String gymId;
  final String clientName;
  final String clientEmail;

  const ClientProgress({
    super.key,
    required this.gymId,
    required this.clientName,
    required this.clientEmail,
  });

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('workout_logs');

  int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int timestampSortValue(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return 0;
  }

  String formatDate(dynamic value, {bool compact = false}) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return compact ? '$day/$month · $hour:$minute' : '$day/$month/$year $hour:$minute';
    }
    return 'Fecha pendiente';
  }

  Future<void> deleteWorkoutLog(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final exercise = data['exercise']?.toString() ?? 'este registro';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Eliminar registro del cliente'),
          content: Text('¿Seguro que quieres eliminar $exercise del historial de $clientName? Esta acción no se puede deshacer.'),
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
        const SnackBar(content: Text('Registro eliminado del cliente.')),
      );
    }
  }

  Widget metricTile({
    required IconData icon,
    required String value,
    required String label,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.greenAccent, size: compact ? 18 : 20),
          SizedBox(height: compact ? 6 : 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: compact ? 17 : 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white60, fontSize: compact ? 11 : 12),
          ),
        ],
      ),
    );
  }

  Widget recentLogTile({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required bool compact,
  }) {
    final data = doc.data();
    final exercise = data['exercise']?.toString() ?? 'Ejercicio';
    final routineTitle = data['routineTitle']?.toString() ?? 'Rutina';
    final weight = data['weight']?.toString() ?? '-';
    final reps = data['reps']?.toString() ?? '-';
    final date = formatDate(data['createdAt'], compact: compact);

    if (compact) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF020617),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.analytics, color: Colors.greenAccent, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$weight kg · $reps reps · $date',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    routineTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              tooltip: 'Eliminar registro',
              onPressed: () => deleteWorkoutLog(context, doc),
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 21),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.greenAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.analytics, color: Colors.greenAccent),
        ),
        title: Text(exercise, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(routineTitle, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  InfoChip(text: '$weight kg'),
                  InfoChip(text: '$reps reps'),
                  InfoChip(text: date),
                ],
              ),
            ],
          ),
        ),
        trailing: IconButton(
          tooltip: 'Eliminar registro',
          onPressed: () => deleteWorkoutLog(context, doc),
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    final normalizedEmail = clientEmail.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(icon: Icons.insights, title: 'Progreso del cliente seleccionado'),
            const SizedBox(height: 12),
            Text(
              '$clientName no tiene email asociado. Añade el email del cliente para poder ver su progreso.',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        WeeklySummary(
          logsRef: logsRef,
          filterField: 'userEmail',
          filterValue: normalizedEmail,
          title: 'Resumen semanal del cliente',
          emptyText: '$clientName no tiene entrenamientos registrados esta semana.',
        ),
        SizedBox(height: isCompact ? 10 : 16),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: logsRef.where('userEmail', isEqualTo: normalizedEmail).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppCard(child: Center(child: CircularProgressIndicator()));
            }

            final logs = [...(snapshot.data?.docs ?? [])];
            logs.sort((a, b) {
              final aDate = timestampSortValue(a.data()['createdAt']);
              final bDate = timestampSortValue(b.data()['createdAt']);
              return bDate.compareTo(aDate);
            });

            if (logs.isEmpty) {
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(icon: Icons.insights, title: 'Progreso del cliente seleccionado'),
                    const SizedBox(height: 12),
                    Text(
                      '$clientName todavía no tiene entrenamientos registrados con el email $normalizedEmail.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              );
            }

            final exercises = <String>{};
            Map<String, dynamic>? bestRecord;
            for (final doc in logs) {
              final data = doc.data();
              final exercise = data['exercise']?.toString().trim() ?? '';
              final weight = intValue(data['weight']);
              final reps = intValue(data['reps']);
              if (exercise.isNotEmpty) exercises.add(exercise);
              if (bestRecord == null ||
                  weight > intValue(bestRecord['weight']) ||
                  (weight == intValue(bestRecord['weight']) && reps > intValue(bestRecord['reps']))) {
                bestRecord = data;
              }
            }

            final latest = logs.first.data();
            final latestDate = formatDate(latest['createdAt'], compact: isCompact);
            final bestExercise = bestRecord?['exercise']?.toString() ?? 'Sin marca';
            final bestWeight = intValue(bestRecord?['weight']);
            final bestReps = intValue(bestRecord?['reps']);
            final recentLogs = logs.take(isCompact ? 6 : 5).toList();

            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(icon: Icons.insights, title: 'Progreso del cliente seleccionado'),
                  SizedBox(height: isCompact ? 6 : 8),
                  Text(
                    isCompact ? clientName : '$clientName · $normalizedEmail',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  SizedBox(height: isCompact ? 10 : 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = isCompact ? 2 : 4;
                      const spacing = 8.0;
                      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          SizedBox(
                            width: width,
                            child: metricTile(
                              icon: Icons.list_alt,
                              value: logs.length.toString(),
                              label: 'Series',
                              compact: isCompact,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: metricTile(
                              icon: Icons.fitness_center,
                              value: exercises.length.toString(),
                              label: 'Ejercicios',
                              compact: isCompact,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: metricTile(
                              icon: Icons.schedule,
                              value: latestDate,
                              label: 'Último',
                              compact: isCompact,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: metricTile(
                              icon: Icons.emoji_events,
                              value: '$bestWeight kg x $bestReps',
                              label: bestExercise,
                              compact: isCompact,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: isCompact ? 12 : 14),
                  Text(
                    'Historial reciente',
                    style: TextStyle(fontSize: isCompact ? 15 : 16, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: isCompact ? 8 : 10),
                  ...recentLogs.map((doc) => recentLogTile(context: context, doc: doc, compact: isCompact)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';

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
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }

    return 0;
  }

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
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

  @override
  Widget build(BuildContext context) {
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

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsRef.where('userEmail', isEqualTo: normalizedEmail).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppCard(
            child: Center(child: CircularProgressIndicator()),
          );
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
        final latestDate = formatDate(latest['createdAt']);
        final bestExercise = bestRecord?['exercise']?.toString() ?? 'Sin marca';
        final bestWeight = intValue(bestRecord?['weight']);
        final bestReps = intValue(bestRecord?['reps']);
        final recentLogs = logs.take(5).toList();

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(icon: Icons.insights, title: 'Progreso del cliente seleccionado'),
              const SizedBox(height: 8),
              Text(
                '$clientName · $normalizedEmail',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoChip(text: '${logs.length} series registradas'),
                  InfoChip(text: '${exercises.length} ejercicios'),
                  InfoChip(text: 'Último: $latestDate'),
                  InfoChip(text: 'Mejor: $bestExercise $bestWeight kg x $bestReps'),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Historial reciente del cliente',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ...recentLogs.map((doc) {
                final data = doc.data();
                final exercise = data['exercise']?.toString() ?? 'Ejercicio';
                final routineTitle = data['routineTitle']?.toString() ?? 'Rutina';
                final weight = data['weight']?.toString() ?? '-';
                final reps = data['reps']?.toString() ?? '-';
                final date = formatDate(data['createdAt']);

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
                    title: Text(
                      exercise,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
              }),
            ],
          ),
        );
      },
    );
  }
}

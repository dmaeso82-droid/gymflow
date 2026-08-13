import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';

class RecentWorkoutHistory extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> logsRef;
  final String userId;

  const RecentWorkoutHistory({
    super.key,
    required this.logsRef,
    required this.userId,
  });

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

  int timestampSortValue(dynamic value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }

    return 0;
  }


  Future<void> editWorkoutLog(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final weightController = TextEditingController(text: data['weight']?.toString() ?? '');
    final repsController = TextEditingController(text: data['reps']?.toString() ?? '');

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.gymSurface,
          title: Text('Editar registro'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: weightController,
                label: 'Peso realizado (kg)',
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 12),
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
              child: Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                final weight = int.tryParse(weightController.text.trim());
                final reps = int.tryParse(repsController.text.trim());

                if (weight == null || reps == null || weight < 0 || reps <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Introduce peso y repeticiones válidas.')),
                  );
                  return;
                }

                Navigator.pop(dialogContext, {'weight': weight, 'reps': reps});
              },
              icon: Icon(Icons.save),
              label: Text('Guardar'),
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
    final data = doc.data();
    final exercise = data['exercise']?.toString() ?? 'este registro';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.gymSurface,
          title: Text('Eliminar registro'),
          content: Text('¿Seguro que quieres eliminar $exercise? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancelar'),
            ),
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

    await logsRef.doc(doc.id).delete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro eliminado.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsRef.where('userId', isEqualTo: userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final logs = [...(snapshot.data?.docs ?? [])];

        logs.sort((a, b) {
          final aDate = timestampSortValue(a.data()['createdAt']);
          final bDate = timestampSortValue(b.data()['createdAt']);
          return bDate.compareTo(aDate);
        });

        final recentLogs = logs.take(20).toList();

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(icon: Icons.history, title: 'Historial reciente'),
              SizedBox(height: 12),
              if (recentLogs.isEmpty)
                Text(
                  'Todavía no hay entrenamientos registrados.',
                  style: TextStyle(color: context.gymMutedText),
                )
              else
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
                        exercise,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(routineTitle, style: TextStyle(color: context.gymMutedText)),
                            SizedBox(height: 6),
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
                            icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                          ),
                        ],
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




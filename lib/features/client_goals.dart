
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';

class ClientGoalsPanel extends StatelessWidget {
  final String gymId;
  final String clientName;
  final String clientEmail;

  const ClientGoalsPanel({
    super.key,
    required this.gymId,
    required this.clientName,
    required this.clientEmail,
  });

  CollectionReference<Map<String, dynamic>> get goalsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('goals');

  CollectionReference<Map<String, dynamic>> get activityRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('activity');

  int timestampSortValue(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return 0;
  }

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day/$month/$year';
    }

    return 'Fecha pendiente';
  }


  Future<Map<String, String>> currentActor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'uid': '', 'name': 'Sistema', 'email': ''};
    var name = user.displayName ?? '';
    final email = (user.email ?? '').toLowerCase();
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final storedName = userDoc.data()?['name']?.toString() ?? '';
      if (storedName.trim().isNotEmpty) name = storedName.trim();
    } catch (_) {}
    if (name.trim().isEmpty) name = email.isEmpty ? 'Entrenador' : email;
    return {'uid': user.uid, 'name': name, 'email': email};
  }

  Map<String, dynamic> auditCreateFields(Map<String, String> actor) => {
        'createdBy': actor['name'] ?? '',
        'createdByUid': actor['uid'] ?? '',
        'updatedBy': actor['name'] ?? '',
        'updatedByUid': actor['uid'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> auditUpdateFields(Map<String, String> actor) => {
        'updatedBy': actor['name'] ?? '',
        'updatedByUid': actor['uid'] ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> activityFields({
    required String type,
    required String target,
    required Map<String, String> actor,
    String? targetId,
    Map<String, dynamic>? metadata,
  }) => {
        'type': type,
        'target': target,
        'targetId': targetId ?? '',
        'targetEmail': clientEmail.toLowerCase(),
        'user': actor['name'] ?? '',
        'userUid': actor['uid'] ?? '',
        'userEmail': actor['email'] ?? '',
        'metadata': metadata ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      };

  Future<void> showGoalDialog(
    BuildContext context, {
    QueryDocumentSnapshot<Map<String, dynamic>>? goalDoc,
  }) async {
    final data = goalDoc?.data();
    final titleController = TextEditingController(text: data?['title']?.toString() ?? '');
    final targetController = TextEditingController(text: data?['targetValue']?.toString() ?? '');
    final notesController = TextEditingController(text: data?['notes']?.toString() ?? '');
    String selectedType = data?['type']?.toString() ?? 'general';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.gymSurface,
              title: Text(goalDoc == null ? 'Crear objetivo' : 'Editar objetivo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTextField(
                      controller: titleController,
                      label: 'Objetivo',
                      hint: 'Ej: Bajar cintura a 85 cm',
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      dropdownColor: context.gymSurface,
                      decoration: InputDecoration(
                        labelText: 'Tipo de objetivo',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'general', child: Text('General')),
                        DropdownMenuItem(value: 'peso', child: Text('Peso corporal')),
                        DropdownMenuItem(value: 'cintura', child: Text('Cintura')),
                        DropdownMenuItem(value: 'fuerza', child: Text('Fuerza')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedType = value);
                      },
                    ),
                    SizedBox(height: 12),
                    AppTextField(
                      controller: targetController,
                      label: 'Valor objetivo',
                      hint: 'Ej: 85, 80 kg, 10 reps...',
                    ),
                    SizedBox(height: 12),
                    AppTextField(
                      controller: notesController,
                      label: 'Notas',
                      hint: 'Opcional',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Introduce el objetivo.')),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, {
                      'title': title,
                      'type': selectedType,
                      'targetValue': targetController.text.trim(),
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
      },
    );

    titleController.dispose();
    targetController.dispose();
    notesController.dispose();

    if (result == null) return;
    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();

    if (goalDoc == null) {
      final goalRef = goalsRef.doc();
      batch.set(goalRef, {
        'clientName': clientName,
        'clientEmail': clientEmail.toLowerCase(),
        'title': result['title'],
        'type': result['type'],
        'targetValue': result['targetValue'],
        'notes': result['notes'],
        'completed': false,
        ...auditCreateFields(actor),
      });
      batch.set(activityRef.doc(), activityFields(
        type: 'goal_created',
        target: result['title']?.toString() ?? 'Objetivo',
        targetId: goalRef.id,
        actor: actor,
        metadata: {
          'clientName': clientName,
          'type': result['type'],
          'targetValue': result['targetValue'],
        },
      ));
    } else {
      batch.update(goalsRef.doc(goalDoc.id), {
        'clientName': clientName,
        'clientEmail': clientEmail.toLowerCase(),
        'title': result['title'],
        'type': result['type'],
        'targetValue': result['targetValue'],
        'notes': result['notes'],
        ...auditUpdateFields(actor),
      });
      batch.set(activityRef.doc(), activityFields(
        type: 'goal_updated',
        target: result['title']?.toString() ?? 'Objetivo',
        targetId: goalDoc.id,
        actor: actor,
        metadata: {
          'clientName': clientName,
          'previousTitle': goalDoc.data()['title'] ?? '',
          'type': result['type'],
          'targetValue': result['targetValue'],
        },
      ));
    }
    await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(goalDoc == null ? 'Objetivo creado.' : 'Objetivo actualizado.')),
      );
    }
  }

  Future<void> toggleGoalCompleted(
    QueryDocumentSnapshot<Map<String, dynamic>> goalDoc,
    bool completed,
  ) async {
    final data = goalDoc.data();
    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(goalsRef.doc(goalDoc.id), {
      'completed': completed,
      'completedAt': completed ? FieldValue.serverTimestamp() : null,
      ...auditUpdateFields(actor),
    });
    batch.set(activityRef.doc(), activityFields(
      type: completed ? 'goal_completed' : 'goal_reopened',
      target: data['title']?.toString() ?? 'Objetivo',
      targetId: goalDoc.id,
      actor: actor,
      metadata: {'clientName': clientName, 'completed': completed},
    ));
    await batch.commit();
  }

  Future<void> deleteGoal(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> goalDoc,
  ) async {
    final data = goalDoc.data();
    final title = data['title']?.toString() ?? 'este objetivo';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.gymSurface,
          title: Text('Eliminar objetivo'),
          content: Text('¿Seguro que quieres eliminar "$title"? Esta acción no se puede deshacer.'),
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

    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(goalsRef.doc(goalDoc.id));
    batch.set(activityRef.doc(), activityFields(
      type: 'goal_deleted',
      target: title,
      targetId: goalDoc.id,
      actor: actor,
      metadata: {'clientName': clientName},
    ));
    await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Objetivo eliminado.')),
      );
    }
  }

  String typeLabel(String type) {
    switch (type) {
      case 'peso':
        return 'Peso corporal';
      case 'cintura':
        return 'Cintura';
      case 'fuerza':
        return 'Fuerza';
      default:
        return 'General';
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
            SectionTitle(icon: Icons.flag, title: 'Objetivos del cliente'),
            SizedBox(height: 12),
            Text(
              'El cliente seleccionado no tiene email asociado. Añade el email del cliente para poder gestionar objetivos.',
              style: TextStyle(color: context.gymMutedText),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: goalsRef.where('clientEmail', isEqualTo: normalizedEmail).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final goals = [...(snapshot.data?.docs ?? [])];

        goals.sort((a, b) {
          final aCompleted = a.data()['completed'] == true;
          final bCompleted = b.data()['completed'] == true;
          if (aCompleted != bCompleted) return aCompleted ? 1 : -1;

          final aDate = timestampSortValue(a.data()['createdAt']);
          final bDate = timestampSortValue(b.data()['createdAt']);
          return bDate.compareTo(aDate);
        });

        final completed = goals.where((goal) => goal.data()['completed'] == true).length;

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(icon: Icons.flag, title: 'Objetivos del cliente'),
              SizedBox(height: 8),
              Text('$clientName · $normalizedEmail', style: TextStyle(color: context.gymMutedText)),
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoChip(text: '${goals.length} objetivos'),
                  InfoChip(text: '$completed completados'),
                  if (goals.isNotEmpty) InfoChip(text: '${goals.length - completed} pendientes'),
                ],
              ),
              SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => showGoalDialog(context),
                  icon: Icon(Icons.add),
                  label: Text('Crear objetivo'),
                ),
              ),
              SizedBox(height: 14),
              if (goals.isEmpty)
                Text(
                  'Todavía no hay objetivos definidos para este cliente.',
                  style: TextStyle(color: context.gymMutedText),
                )
              else
                ...goals.map((goalDoc) {
                  final data = goalDoc.data();
                  final completed = data['completed'] == true;
                  final title = data['title']?.toString() ?? 'Objetivo';
                  final type = data['type']?.toString() ?? 'general';
                  final targetValue = data['targetValue']?.toString() ?? '';
                  final notes = data['notes']?.toString() ?? '';
                  final createdAt = formatDate(data['createdAt']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: context.gymSubtleSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: completed ? context.gymPrimary.withValues(alpha: 0.35) : context.gymBorder),
                    ),
                    child: ListTile(
                      leading: IconButton(
                        onPressed: () => toggleGoalCompleted(goalDoc, !completed),
                        icon: Icon(
                          completed ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: completed ? context.gymPrimary : context.gymMutedText.withValues(alpha: 0.85),
                        ),
                      ),
                      title: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: completed ? TextDecoration.lineThrough : TextDecoration.none,
                          color: completed ? context.gymPrimary : context.gymText,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                InfoChip(text: typeLabel(type)),
                                if (targetValue.isNotEmpty) InfoChip(text: 'Meta: $targetValue'),
                                InfoChip(text: createdAt),
                                if ((data['createdBy'] ?? '').toString().isNotEmpty)
                                  InfoChip(text: 'Creado por ${data['createdBy']}'),
                                if ((data['updatedBy'] ?? '').toString().isNotEmpty)
                                  InfoChip(text: 'Actualizado por ${data['updatedBy']}'),
                              ],
                            ),
                            if (notes.isNotEmpty) ...[
                              SizedBox(height: 6),
                              Text(notes, style: TextStyle(color: context.gymMutedText)),
                            ],
                          ],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar objetivo',
                            onPressed: () => showGoalDialog(context, goalDoc: goalDoc),
                            icon: Icon(Icons.edit, color: context.gymPrimary),
                          ),
                          IconButton(
                            tooltip: 'Eliminar objetivo',
                            onPressed: () => deleteGoal(context, goalDoc),
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




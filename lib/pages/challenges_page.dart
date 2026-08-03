
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/profile_avatar.dart';

class ChallengesPage extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;
  final bool trainerMode;

  const ChallengesPage({
    super.key,
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.trainerMode = false,
  });

  CollectionReference<Map<String, dynamic>> get challengesRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('challenges');

  CollectionReference<Map<String, dynamic>> get communityRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('community_posts');

  int intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
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

  Future<void> createChallenge(BuildContext context) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final targetController = TextEditingController(text: '12');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Crear reto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    hintText: 'Reto Agosto',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Completar entrenamientos durante el mes.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Objetivo de entrenamientos',
                    hintText: '12',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'En esta primera versión los retos son de tipo “entrenamientos completados”.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
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
                final title = titleController.text.trim();
                final description = descriptionController.text.trim();
                final target = int.tryParse(targetController.text.trim()) ?? 0;
                if (title.isEmpty || target <= 0) return;
                Navigator.pop(dialogContext, {
                  'title': title,
                  'description': description,
                  'target': target,
                });
              },
              icon: const Icon(Icons.emoji_events),
              label: const Text('Crear reto'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    targetController.dispose();

    if (result == null) return;

    await challengesRef.add({
      'title': result['title'],
      'description': result['description'],
      'type': 'workout_count',
      'target': result['target'],
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reto creado.')),
      );
    }
  }

  Future<void> toggleChallengeActive(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool active,
  ) async {
    await challengesRef.doc(doc.id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteChallenge(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final title = doc.data()['title']?.toString() ?? 'este reto';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Eliminar reto'),
          content: Text('¿Seguro que quieres eliminar "$title"?'),
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
    await challengesRef.doc(doc.id).delete();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      appBar: AppBar(title: const Text('Retos')),
      floatingActionButton: trainerMode
          ? FloatingActionButton.extended(
              onPressed: () => createChallenge(context),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo reto'),
            )
          : null,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: challengesRef.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final allChallenges = snapshot.data?.docs ?? [];
            final challenges = trainerMode
                ? allChallenges
                : allChallenges.where((doc) => doc.data()['active'] != false).toList();

            return ListView(
              padding: EdgeInsets.all(isCompact ? 12 : 16),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.emoji_events, color: Colors.amberAccent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trainerMode ? 'Retos del gimnasio' : 'Mis retos',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              trainerMode
                                  ? 'Crea retos para motivar a toda la comunidad de DalaiGym.'
                                  : 'Completa entrenamientos y desbloquea los retos activos.',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isCompact ? 10 : 16),
                if (challenges.isEmpty)
                  AppCard(
                    child: Text(
                      trainerMode
                          ? 'Todavía no hay retos creados. Pulsa “Nuevo reto” para crear el primero.'
                          : 'Todavía no hay retos activos.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                else
                  ...challenges.map((doc) {
                    if (trainerMode) {
                      return TrainerChallengeCard(
                        doc: doc,
                        onToggleActive: (active) => toggleChallengeActive(doc, active),
                        onDelete: () => deleteChallenge(context, doc),
                        formatDate: formatDate,
                      );
                    }
                    return UserChallengeCard(
                      challengeDoc: doc,
                      userId: userId,
                      userName: userName,
                      userEmail: userEmail,
                      formatDate: formatDate,
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class TrainerChallengeCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDelete;
  final String Function(dynamic value) formatDate;

  const TrainerChallengeCard({
    super.key,
    required this.doc,
    required this.onToggleActive,
    required this.onDelete,
    required this.formatDate,
  });

  int intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final title = data['title']?.toString() ?? 'Reto';
    final description = data['description']?.toString() ?? '';
    final target = intValue(data['target']);
    final active = data['active'] != false;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.emoji_events, color: Colors.amberAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(description, style: const TextStyle(color: Colors.white70)),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                  if (value == 'toggle') onToggleActive(!active);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(active ? 'Desactivar' : 'Activar'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Eliminar'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChallengeChip(text: '$target entrenamientos'),
              _ChallengeChip(text: active ? 'Activo' : 'Inactivo'),
              _ChallengeChip(text: 'Creado ${formatDate(data['createdAt'])}'),
            ],
          ),
        ],
      ),
    );
  }
}

class UserChallengeCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> challengeDoc;
  final String userId;
  final String userName;
  final String userEmail;
  final String Function(dynamic value) formatDate;

  const UserChallengeCard({
    super.key,
    required this.challengeDoc,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.formatDate,
  });

  int intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final data = challengeDoc.data();
    final title = data['title']?.toString() ?? 'Reto';
    final description = data['description']?.toString() ?? '';
    final target = intValue(data['target'], fallback: 1);
    final progressRef = challengeDoc.reference.collection('progress').doc(userId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: progressRef.snapshots(),
      builder: (context, snapshot) {
        final progressData = snapshot.data?.data();
        final count = intValue(progressData?['count']);
        final completed = progressData?['completed'] == true;
        final percent = target <= 0 ? 0.0 : (count / target).clamp(0.0, 1.0);

        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileAvatar(name: userName, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(description, style: const TextStyle(color: Colors.white70)),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    completed ? Icons.emoji_events : Icons.flag,
                    color: completed ? Colors.amberAccent : Colors.greenAccent,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 10,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completed ? Colors.amberAccent : Colors.greenAccent,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$count / $target entrenamientos',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${(percent * 100).round()}%',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              if (completed && progressData?['completedAt'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Completado el ${formatDate(progressData?['completedAt'])}',
                  style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ChallengeChip extends StatelessWidget {
  final String text;
  const _ChallengeChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

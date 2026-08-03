
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';

class NotificationsPage extends StatefulWidget {
  final String gymId;

  const NotificationsPage({super.key, required this.gymId});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String selectedFilter = 'all';

  DocumentReference<Map<String, dynamic>> get readRef {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notification_reads')
        .doc(widget.gymId);
  }

  CollectionReference<Map<String, dynamic>> get activityRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('activity');

  @override
  void initState() {
    super.initState();
    markAllAsRead();
  }

  Future<void> markAllAsRead() async {
    await readRef.set({
      'lastReadAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String activityGroup(String type) {
    if (type.startsWith('client_')) return 'clients';
    if (type.startsWith('routine_')) return 'routines';
    if (type.startsWith('template_')) return 'templates';
    if (type.startsWith('measurement_')) return 'measurements';
    if (type.startsWith('goal_')) return 'goals';
    return 'other';
  }

  String activityTitle(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final user = data['user']?.toString() ?? 'Alguien';
    final target = data['target']?.toString() ?? 'un elemento';

    switch (type) {
      case 'client_created':
        return '$user creó el cliente $target';
      case 'client_updated':
        return '$user actualizó el cliente $target';
      case 'client_deleted':
        return '$user eliminó el cliente $target';
      case 'routine_created':
        return '$user creó la rutina $target';
      case 'routine_generated':
        final metadata = data['metadata'];
        final clientName = metadata is Map ? metadata['clientName']?.toString() : null;
        return clientName == null || clientName.isEmpty
            ? '$user generó una rutina automática'
            : '$user generó una rutina para $clientName';
      case 'routine_updated':
        return '$user actualizó la rutina $target';
      case 'routine_deleted':
        return '$user eliminó la rutina $target';
      case 'routine_exercise_added':
        return '$user añadió $target a una rutina';
      case 'routine_exercise_updated':
        return '$user actualizó $target en una rutina';
      case 'routine_exercise_deleted':
        return '$user eliminó $target de una rutina';
      case 'template_created':
        return '$user creó la plantilla $target';
      case 'template_renamed':
        return '$user renombró la plantilla $target';
      case 'template_duplicated':
        return '$user duplicó la plantilla $target';
      case 'template_deleted':
        return '$user eliminó la plantilla $target';
      case 'template_day_updated':
        return '$user actualizó un día de $target';
      case 'template_exercise_added':
        return '$user añadió $target a una plantilla';
      case 'template_exercise_updated':
        return '$user actualizó $target en una plantilla';
      case 'template_exercise_deleted':
        return '$user eliminó $target de una plantilla';
      case 'template_exercise_moved':
        return '$user reordenó $target en una plantilla';
      case 'measurement_created':
        return '$user registró medidas de $target';
      case 'measurement_deleted':
        return '$user eliminó medidas de $target';
      case 'goal_created':
        return '$user creó el objetivo $target';
      case 'goal_updated':
        return '$user actualizó el objetivo $target';
      case 'goal_completed':
        return '$user completó el objetivo $target';
      case 'goal_reopened':
        return '$user reabrió el objetivo $target';
      case 'goal_deleted':
        return '$user eliminó el objetivo $target';
      default:
        return '$user realizó una acción sobre $target';
    }
  }

  IconData activityIcon(String type) {
    if (type.startsWith('client_')) return Icons.person;
    if (type.startsWith('routine_')) return Icons.fitness_center;
    if (type.startsWith('template_')) return Icons.tune;
    if (type.startsWith('measurement_')) return Icons.monitor_weight;
    if (type.startsWith('goal_')) return Icons.flag;
    return Icons.notifications;
  }

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year · $hour:$minute';
    }
    return 'Fecha pendiente';
  }

  List<Map<String, String>> get filters => const [
        {'id': 'all', 'label': 'Todos'},
        {'id': 'clients', 'label': 'Clientes'},
        {'id': 'routines', 'label': 'Rutinas'},
        {'id': 'templates', 'label': 'Plantillas'},
        {'id': 'goals', 'label': 'Objetivos'},
        {'id': 'measurements', 'label': 'Medidas'},
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          TextButton.icon(
            onPressed: markAllAsRead,
            icon: const Icon(Icons.done_all),
            label: const Text('Marcar leído'),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: activityRef.orderBy('createdAt', descending: true).limit(80).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final activityDocs = snapshot.data?.docs ?? [];
            final filteredDocs = selectedFilter == 'all'
                ? activityDocs
                : activityDocs.where((doc) {
                    final type = doc.data()['type']?.toString() ?? '';
                    return activityGroup(type) == selectedFilter;
                  }).toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.notifications, color: Colors.greenAccent),
                          SizedBox(width: 8),
                          Text(
                            'Centro de notificaciones',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Últimos movimientos del gimnasio registrados por entrenadores.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: filters.map((filter) {
                          final selected = selectedFilter == filter['id'];
                          return ChoiceChip(
                            label: Text(filter['label']!),
                            selected: selected,
                            onSelected: (_) => setState(() => selectedFilter = filter['id']!),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (filteredDocs.isEmpty)
                  const AppCard(
                    child: Text(
                      'No hay notificaciones para este filtro.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                else
                  ...filteredDocs.map((doc) {
                    final data = doc.data();
                    final type = data['type']?.toString() ?? '';
                    final title = activityTitle(data);
                    final dateText = formatDate(data['createdAt']);

                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(activityIcon(type), color: Colors.greenAccent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 4),
                                Text(dateText, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
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

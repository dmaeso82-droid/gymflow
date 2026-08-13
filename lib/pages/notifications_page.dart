import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../services/notification_service.dart';
import '../widgets/app_card.dart';

class NotificationsPage extends StatefulWidget {
  final String gymId;

  const NotificationsPage({super.key, required this.gymId});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String selectedFilter = 'all';

  NotificationService get notificationService => NotificationService(gymId: widget.gymId);

  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get currentUserEmail => (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase();

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

  CollectionReference<Map<String, dynamic>> get notificationsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('notifications');

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

    await notificationService.markAllAsRead(
      userId: currentUserId,
      userEmail: currentUserEmail,
    );
  }

  String activityGroup(String type) {
    if (type.startsWith('client_')) return 'activity';
    if (type.startsWith('routine_')) return 'activity';
    if (type.startsWith('template_')) return 'activity';
    if (type.startsWith('measurement_')) return 'measurements';
    if (type.startsWith('goal_')) return 'goals';
    return 'activity';
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

  Color activityColor(BuildContext context, String type) {
    if (type.startsWith('measurement_')) return Colors.lightBlueAccent;
    if (type.startsWith('goal_')) return context.gymPrimary;
    return context.gymPrimary;
  }

  List<Map<String, String>> get filters => const [
        {'id': 'all', 'label': 'Todo'},
        {'id': 'activity', 'label': 'Actividad'},
        {'id': 'messages', 'label': 'Mensajes'},
        {'id': 'challenges', 'label': 'Retos'},
        {'id': 'rankings', 'label': 'Ranking'},
        {'id': 'community', 'label': 'Comunidad'},
        {'id': 'goals', 'label': 'Objetivos'},
        {'id': 'measurements', 'label': 'Medidas'},
      ];

  List<NotificationItem> buildItems({
    required BuildContext context,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> notificationDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> activityDocs,
  }) {
    final items = <NotificationItem>[];

    for (final doc in notificationDocs) {
      final data = doc.data();
      if (!notificationService.isForCurrentUser(data, currentUserId, currentUserEmail)) continue;
      final type = data['type']?.toString() ?? 'notification';
      items.add(NotificationItem(
        group: notificationService.groupForType(type),
        title: data['title']?.toString() ?? 'Notificación',
        message: data['message']?.toString() ?? '',
        dateText: notificationService.formatDate(data['createdAt']),
        createdAt: data['createdAt'],
        icon: notificationService.iconForType(type),
        color: notificationService.colorForType(type),
        read: data['read'] == true,
      ));
    }

    for (final doc in activityDocs) {
      final data = doc.data();
      final type = data['type']?.toString() ?? '';
      items.add(NotificationItem(
        group: activityGroup(type),
        title: activityTitle(data),
        message: 'Movimiento registrado en DalaiGym',
        dateText: notificationService.formatDate(data['createdAt']),
        createdAt: data['createdAt'],
        icon: activityIcon(type),
        color: activityColor(context, type),
        read: true,
      ));
    }

    items.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      final aMs = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
      final bMs = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;
      return bMs.compareTo(aMs);
    });

    if (selectedFilter == 'all') return items;
    return items.where((item) => item.group == selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notificaciones'),
        actions: [
          TextButton.icon(
            onPressed: markAllAsRead,
            icon: Icon(Icons.done_all),
            label: Text('Marcar leído'),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: notificationsRef.orderBy('createdAt', descending: true).limit(80).snapshots(),
          builder: (context, notificationSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: activityRef.orderBy('createdAt', descending: true).limit(80).snapshots(),
              builder: (context, activitySnapshot) {
                if (notificationSnapshot.connectionState == ConnectionState.waiting ||
                    activitySnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final items = buildItems(
                  context: context,
                  notificationDocs: notificationSnapshot.data?.docs ?? [],
                  activityDocs: activitySnapshot.data?.docs ?? [],
                );

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notifications, color: context.gymPrimary),
                              SizedBox(width: 8),
                              Text(
                                'Centro de notificaciones',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Mensajes, retos, comunidad y últimos movimientos del gimnasio.',
                            style: TextStyle(color: context.gymMutedText),
                          ),
                          SizedBox(height: 14),
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
                    SizedBox(height: 16),
                    if (items.isEmpty)
                      AppCard(
                        child: Text(
                          'No hay notificaciones para este filtro.',
                          style: TextStyle(color: context.gymMutedText),
                        ),
                      )
                    else
                      ...items.map((item) => NotificationTile(item: item)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class NotificationItem {
  final String group;
  final String title;
  final String message;
  final String dateText;
  final dynamic createdAt;
  final IconData icon;
  final Color color;
  final bool read;

  const NotificationItem({
    required this.group,
    required this.title,
    required this.message,
    required this.dateText,
    required this.createdAt,
    required this.icon,
    required this.color,
    required this.read,
  });
}

class NotificationTile extends StatelessWidget {
  final NotificationItem item;

  const NotificationTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: item.read ? 0.10 : 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: item.read ? FontWeight.w800 : FontWeight.w900,
                          color: item.read ? context.gymText : context.gymPrimary,
                        ),
                      ),
                    ),
                    if (!item.read)
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(color: context.gymPrimary, shape: BoxShape.circle),
                      ),
                  ],
                ),
                if (item.message.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(item.message, style: TextStyle(color: context.gymMutedText)),
                ],
                SizedBox(height: 4),
                Text(item.dateText, style: TextStyle(color: context.gymMutedText, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}




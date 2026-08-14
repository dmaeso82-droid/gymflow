part of '../trainer_home_page.dart';

class NotificationsBell extends StatelessWidget {
  final String gymId;
  const NotificationsBell({super.key, required this.gymId});

  DocumentReference<Map<String, dynamic>> get readRef {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('notification_reads').doc(gymId);
  }

  CollectionReference<Map<String, dynamic>> get activityRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('activity');

  void openNotifications(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsPage(gymId: gymId)));
  }

  int unreadCount(List<QueryDocumentSnapshot<Map<String, dynamic>>> activities, Timestamp? lastReadAt) {
    if (lastReadAt == null) return activities.length;
    final lastReadMillis = lastReadAt.millisecondsSinceEpoch;
    return activities.where((doc) {
      final createdAt = doc.data()['createdAt'];
      if (createdAt is! Timestamp) return false;
      return createdAt.millisecondsSinceEpoch > lastReadMillis;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: readRef.snapshots(),
      builder: (context, readSnapshot) {
        final readData = readSnapshot.data?.data();
        final lastReadAt = readData?['lastReadAt'] is Timestamp ? readData!['lastReadAt'] as Timestamp : null;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: activityRef.orderBy('createdAt', descending: true).limit(50).snapshots(),
          builder: (context, activitySnapshot) {
            final activities = activitySnapshot.data?.docs ?? [];
            final count = unreadCount(activities, lastReadAt);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Notificaciones',
                  onPressed: () => openNotifications(context),
                  icon: const Icon(Icons.notifications),
                ),
                if (count > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(999)),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(count > 99 ? '99+' : count.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../features/recent_workout_history.dart';

class UserHistoryPage extends StatelessWidget {
  final String gymId;
  final String userId;

  const UserHistoryPage({super.key, required this.gymId, required this.userId});

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('workout_logs');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Historial')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            RecentWorkoutHistory(logsRef: logsRef, userId: userId),
          ],
        ),
      ),
    );
  }
}




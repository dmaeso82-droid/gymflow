import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../features/exercise_progress.dart';

class UserProgressPage extends StatelessWidget {
  final String gymId;
  final String userId;

  const UserProgressPage({super.key, required this.gymId, required this.userId});

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('workout_logs');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Evolución')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ExerciseProgress(logsRef: logsRef, userId: userId),
          ],
        ),
      ),
    );
  }
}

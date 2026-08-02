import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../features/personal_records.dart';

class UserRecordsPage extends StatelessWidget {
  final String gymId;
  final String userId;

  const UserRecordsPage({super.key, required this.gymId, required this.userId});

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('workout_logs');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Récords personales')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PersonalRecords(logsRef: logsRef, userId: userId),
          ],
        ),
      ),
    );
  }
}

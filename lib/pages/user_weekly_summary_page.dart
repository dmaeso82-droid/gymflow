import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../features/weekly_summary.dart';

class UserWeeklySummaryPage extends StatelessWidget {
  final String gymId;
  final String userId;

  const UserWeeklySummaryPage({super.key, required this.gymId, required this.userId});

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('workout_logs');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Resumen semanal')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            WeeklySummary(
              logsRef: logsRef,
              filterField: 'userId',
              filterValue: userId,
              title: 'Resumen semanal',
            ),
          ],
        ),
      ),
    );
  }
}




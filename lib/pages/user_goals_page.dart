import 'package:flutter/material.dart';

import '../features/client_goals_user.dart';

class UserGoalsPage extends StatelessWidget {
  final String gymId;
  final String userEmail;

  const UserGoalsPage({super.key, required this.gymId, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis objetivos')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClientGoalsUserPanel(gymId: gymId, userEmail: userEmail),
          ],
        ),
      ),
    );
  }
}

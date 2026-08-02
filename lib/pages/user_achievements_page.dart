
import 'package:flutter/material.dart';

import '../features/user_achievements.dart';

class UserAchievementsPage extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userEmail;

  const UserAchievementsPage({
    super.key,
    required this.gymId,
    required this.userId,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis logros')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            UserAchievementsPanel(
              gymId: gymId,
              userId: userId,
              userEmail: userEmail,
            ),
          ],
        ),
      ),
    );
  }
}

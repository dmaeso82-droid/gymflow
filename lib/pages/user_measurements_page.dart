import 'package:flutter/material.dart';

import '../features/body_measurements.dart';
import 'progress_photos_page.dart';

class UserMeasurementsPage extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;

  const UserMeasurementsPage({
    super.key,
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Progreso físico')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BodyMeasurementsPanel(
              gymId: gymId,
              filterField: 'userId',
              filterValue: userId,
              title: 'Progreso físico',
              emptyText: 'Todavía no tienes medidas corporales registradas.',
              allowAdd: true,
              userId: userId,
              userName: userName,
              userEmail: userEmail,
            ),
            SizedBox(height: 16),
            ProgressPhotosPanel(
              gymId: gymId,
              userId: userId,
              userName: userName,
              userEmail: userEmail,
              allowAdd: true,
            ),
          ],
        ),
      ),
    );
  }
}




import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import 'auth_page.dart';
import 'loading_page.dart';
import 'trainer_home_page.dart';
import 'user_home_page.dart';

class RoleGatePage extends StatelessWidget {
  const RoleGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final uid = currentUser.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingPage();

        final data = snapshot.data!.data();
        if (data == null) return const AuthPage();

        final role = data['role'] as String? ?? 'user';
        final gymId = data['gymId'] as String? ?? demoGymId;
        final name = data['name'] as String? ?? 'Usuario';
        final email = (data['email'] as String? ?? currentUser.email ?? '').toLowerCase();

        if (role == 'trainer') {
          return TrainerHomePage(gymId: gymId, trainerName: name);
        }

        return UserHomePage(
          gymId: gymId,
          userId: uid,
          userName: name,
          userEmail: email,
        );
      },
    );
  }
}

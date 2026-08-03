
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
        final trainerRole = data['trainerRole'] as String? ?? 'trainer';
        final active = data['active'] != false;
        final gymId = data['gymId'] as String? ?? defaultGymId;
        final name = data['name'] as String? ?? 'Usuario';
        final email = (data['email'] as String? ?? currentUser.email ?? '').toLowerCase();

        if (!active) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.block, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      const Text(
                        'Cuenta desactivada',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Contacta con el administrador del gimnasio para volver a activar el acceso.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (role == 'trainer') {
          return TrainerHomePage(gymId: gymId, trainerName: name, trainerRole: trainerRole);
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('gyms')
              .doc(gymId)
              .collection('clients')
              .where('email', isEqualTo: email)
              .limit(1)
              .snapshots(),
          builder: (context, clientSnapshot) {
            var displayName = name;
            if (clientSnapshot.hasData && clientSnapshot.data!.docs.isNotEmpty) {
              final clientData = clientSnapshot.data!.docs.first.data();
              displayName = clientData['name']?.toString() ?? name;
            }

            return UserHomePage(
              gymId: gymId,
              userId: uid,
              userName: displayName,
              userEmail: email,
            );
          },
        );
      },
    );
  }
}

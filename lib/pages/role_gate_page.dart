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
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const LoadingPage();
    }
    final uid = currentUser.uid;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ConnectionRecoveryPage(
            message: 'No se ha podido recuperar tu sesión. Toca para reintentar.',
            onRetry: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const RoleGatePage()),
              );
            },
          );
        }
        if (!snapshot.hasData) return const LoadingPage();
        final data = snapshot.data!.data();
        if (data == null) return const _MissingTenantPage();
        final role = data['role'] as String? ?? roleUser;
        final trainerRole = data['trainerRole'] as String? ?? trainerRoleTrainer;
        final active = data['active'] != false;
        final gymId = data['gymId']?.toString().trim() ?? '';
        final name = data['name'] as String? ?? 'Usuario';
        final email = (data['email'] as String? ?? currentUser.email ?? '').toLowerCase();
        if (gymId.isEmpty) return const _MissingTenantPage();
        if (!active) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block, size: 48, color: Colors.redAccent),
                      SizedBox(height: 16),
                      Text(
                        'Cuenta desactivada',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Contacta con el administrador del gimnasio para volver a activar el acceso.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                      SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        icon: Icon(Icons.logout),
                        label: Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('gyms').doc(gymId).snapshots(),
          builder: (context, gymSnapshot) {
            if (gymSnapshot.hasError) {
              return _ConnectionRecoveryPage(
                message: 'No se ha podido cargar el gimnasio asociado a tu cuenta.',
                onRetry: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const RoleGatePage()),
                  );
                },
              );
            }
            if (!gymSnapshot.hasData) return const LoadingPage();
            final gymData = gymSnapshot.data!.data();
            if (gymData == null) return const _MissingTenantPage();
            final gymActive = (gymData['status'] ?? 'active').toString() == 'active';
            if (!gymActive) return const _InactiveGymPage();
            if (role == roleOwner || role == roleTrainer) {
              final effectiveTrainerRole = role == roleOwner ? trainerRoleGymAdmin : trainerRole;
              return TrainerHomePage(gymId: gymId, trainerName: name, trainerRole: effectiveTrainerRole);
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
                if (clientSnapshot.hasError) {
                  return UserHomePage(
                    gymId: gymId,
                    userId: uid,
                    userName: name,
                    userEmail: email,
                  );
                }
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
      },
    );
  }
}
class _MissingTenantPage extends StatelessWidget {
  const _MissingTenantPage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_outlined, size: 48, color: Colors.orangeAccent),
                SizedBox(height: 16),
                Text('Cuenta sin gimnasio asociado', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('Cierra sesión y registra un gimnasio nuevo, o pide al administrador que te asigne a uno existente.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                SizedBox(height: 18),
                FilledButton.icon(onPressed: () => FirebaseAuth.instance.signOut(), icon: Icon(Icons.logout), label: Text('Cerrar sesión')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _InactiveGymPage extends StatelessWidget {
  const _InactiveGymPage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pause_circle_outline, size: 48, color: Colors.orangeAccent),
                SizedBox(height: 16),
                Text('Gimnasio no activo', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('El gimnasio asociado a esta cuenta no está activo actualmente.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                SizedBox(height: 18),
                FilledButton.icon(onPressed: () => FirebaseAuth.instance.signOut(), icon: Icon(Icons.logout), label: Text('Cerrar sesión')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _ConnectionRecoveryPage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ConnectionRecoveryPage({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.orangeAccent, size: 46),
                SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: Icon(Icons.refresh),
                  label: Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

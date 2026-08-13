import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/challenge_service.dart';
import '../services/duel_service.dart';
import '../widgets/app_card.dart';
import '../widgets/challenge_card.dart';
import '../widgets/challenge_creation_dialog.dart';
import '../widgets/duel_card.dart';
import '../widgets/duel_creation_dialog.dart';

class ChallengesPage extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;
  final bool trainerMode;

  const ChallengesPage({
    super.key,
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.trainerMode = false,
  });

  ChallengeService get service => ChallengeService(gymId: gymId, userEmail: userEmail);
  DuelService get duelService => DuelService(gymId: gymId);

  Future<void> createChallenge(BuildContext context) async {
    final challengeService = service;
    final result = await showChallengeCreationDialog(context: context, service: challengeService);
    if (result == null) return;

    await challengeService.createChallenge(
      title: result.title,
      description: result.description,
      type: result.type,
      target: result.target,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reto creado.')));
    }
  }

  Future<void> deleteChallenge(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final challengeService = service;
    final title = doc.data()['title']?.toString() ?? 'este reto';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.gymSurface,
          title: Text('Eliminar reto'),
          content: Text('¿Seguro que quieres eliminar "$title"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('Cancelar')),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: Icon(Icons.delete_outline),
              label: Text('Eliminar'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    await challengeService.deleteChallenge(doc.id);
  }

  Future<void> createDuel(BuildContext context) async {
    final result = await showDuelCreationDialog(
      context: context,
      service: duelService,
      currentUserId: userId,
      currentUserName: userName,
      currentUserEmail: userEmail,
      trainerMode: trainerMode,
    );
    if (result == null) return;

    await duelService.createDuel(
      challenger: result.challenger,
      opponent: result.opponent,
      metric: result.metric,
      target: result.target,
      points: result.points,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duelo creado.')));
    }
  }

  Future<void> showNewActionMenu(BuildContext context) async {
    if (!trainerMode) {
      await createDuel(context);
      return;
    }

    final option = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.gymSurface,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Crear nuevo', style: TextStyle(color: context.gymText, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                _NewChallengeActionTile(
                  icon: Icons.emoji_events,
                  iconColor: Colors.amberAccent,
                  title: 'Nuevo reto global',
                  subtitle: 'Crear un reto para todo el gimnasio',
                  onTap: () => Navigator.pop(sheetContext, 'challenge'),
                ),
                const SizedBox(height: 8),
                _NewChallengeActionTile(
                  icon: Icons.sports_mma,
                  iconColor: context.gymPrimary,
                  title: 'Nuevo duelo 1 vs 1',
                  subtitle: 'Retar a dos clientes entre sí',
                  onTap: () => Navigator.pop(sheetContext, 'duel'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (option == 'challenge') createChallenge(context);
    if (option == 'duel') createDuel(context);
  }

  @override
  Widget build(BuildContext context) {
    final challengeService = service;
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(title: Text('Retos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showNewActionMenu(context),
        icon: Icon(Icons.add),
        label: Text('Nuevo'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: challengeService.challengesRef.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            final allChallenges = snapshot.data?.docs ?? [];
            final challenges = trainerMode
                ? allChallenges
                : allChallenges.where((doc) => doc.data()['active'] != false).toList();

            return FutureBuilder<ChallengeStats>(
              future: trainerMode ? Future.value(ChallengeStats.empty()) : challengeService.loadUserStats(),
              builder: (context, statsSnapshot) {
                final stats = statsSnapshot.data ?? ChallengeStats.empty();
                if (!trainerMode && statsSnapshot.hasData) {
                  Future.microtask(() => challengeService.completeEligibleChallenges(
                        challenges: challenges,
                        stats: stats,
                        userId: userId,
                        userName: userName,
                        userEmail: userEmail,
                      ));
                }

                return ListView(
                  padding: EdgeInsets.all(isCompact ? 12 : 16),
                  children: [
                    AppCard(
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.amberAccent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.emoji_events, color: Colors.amberAccent),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trainerMode ? 'Retos del gimnasio' : 'Mis retos',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  trainerMode
                                      ? 'Crea retos de entrenamientos, volumen, series, rachas, objetivos o mediciones.'
                                      : 'Completa entrenamientos, desbloquea retos activos y reta a otros clientes de DalaiGym.',
                                  style: TextStyle(color: context.gymMutedText),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isCompact ? 10 : 16),
                    if (challenges.isEmpty)
                      AppCard(
                        child: Text(
                          trainerMode
                              ? 'Todavía no hay retos creados. Pulsa "Nuevo reto" para crear el primero.'
                              : 'Todavía no hay retos activos.',
                          style: TextStyle(color: context.gymMutedText),
                        ),
                      )
                    else
                      ...challenges.map((doc) {
                        if (trainerMode) {
                          return TrainerChallengeCard(
                            doc: doc,
                            service: challengeService,
                            onToggleActive: (active) => challengeService.toggleChallengeActive(doc.id, active),
                            onDelete: () => deleteChallenge(context, doc),
                          );
                        }
                        return UserChallengeCard(
                          challengeDoc: doc,
                          userName: userName,
                          stats: stats,
                          service: challengeService,
                        );
                      }),
                    SizedBox(height: 16),
                    Text('Duelos 1 vs 1', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    SizedBox(height: 10),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: duelService.duelsRef.orderBy('createdAt', descending: true).snapshots(),
                      builder: (context, duelSnapshot) {
                        if (duelSnapshot.connectionState == ConnectionState.waiting) {
                          return Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final duels = duelSnapshot.data?.docs ?? [];
                        if (duels.isEmpty) {
                          return AppCard(
                            child: Text('Todavía no hay duelos 1 vs 1.', style: TextStyle(color: context.gymMutedText)),
                          );
                        }

                        return Column(
                          children: duels.map((doc) => DuelCard(doc: doc, service: duelService)).toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}




class _NewChallengeActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NewChallengeActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.gymSubtleSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.gymBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.gymMutedText.withValues(alpha: 0.70)),
          ],
        ),
      ),
    );
  }
}

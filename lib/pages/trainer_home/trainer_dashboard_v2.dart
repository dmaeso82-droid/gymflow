part of '../trainer_home_page.dart';

class TrainerDashboardV2 extends StatelessWidget {
  final String greeting;
  final Stream<QuerySnapshot<Map<String, dynamic>>> trainersStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> clientsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> routinesStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> goalsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> userStatsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> activityStream;
  final VoidCallback onOpenClients;
  final VoidCallback onOpenRoutines;
  final void Function(String clientId, String clientName) onOpenRoutineForClient;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenTrainers;

  const TrainerDashboardV2({
    super.key,
    required this.greeting,
    required this.trainersStream,
    required this.clientsStream,
    required this.routinesStream,
    required this.goalsStream,
    required this.userStatsStream,
    required this.activityStream,
    required this.onOpenClients,
    required this.onOpenRoutines,
    required this.onOpenRoutineForClient,
    required this.onOpenGoals,
    required this.onOpenTrainers,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: clientsStream,
      builder: (context, clientsSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: routinesStream,
          builder: (context, routinesSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: goalsStream,
              builder: (context, goalsSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: trainersStream,
                  builder: (context, trainersSnapshot) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: userStatsStream,
                      builder: (context, statsSnapshot) {
                        final clients = clientsSnapshot.data?.docs ?? [];
                        final routines = routinesSnapshot.data?.docs ?? [];
                        final goals = goalsSnapshot.data?.docs ?? [];
                        final trainers = trainersSnapshot.data?.docs ?? [];
                        final stats = statsSnapshot.data?.docs ?? [];
                        final activeClients = clients.where((doc) => doc.data()['active'] != false).toList();
                        final activeRoutines = routines.where((doc) => (doc.data()['status'] ?? 'active').toString() != 'archived').toList();
                        final pendingGoals = goals.where((doc) => doc.data()['completed'] != true).toList();
                        final activeTrainers = trainers.where((doc) => doc.data()['active'] != false).length;
                        final clientsWithRoutine = activeRoutines.map((doc) => (doc.data()['clientId'] ?? '').toString()).where((id) => id.isNotEmpty).toSet();
                        final clientsWithoutRoutine = activeClients.where((doc) => !clientsWithRoutine.contains(doc.id)).toList();
                        final completion = activeClients.isEmpty ? 0.0 : (clientsWithRoutine.length / activeClients.length).clamp(0.0, 1.0);
                        final statsByKey = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
                        for (final doc in stats) {
                          final data = doc.data();
                          final userId = data['userId']?.toString() ?? '';
                          final email = (data['userEmail'] ?? '').toString().toLowerCase();
                          statsByKey[doc.id] = doc;
                          if (userId.isNotEmpty) statsByKey[userId] = doc;
                          if (email.isNotEmpty) statsByKey[email] = doc;
                        }
                        Timestamp? timestampValue(dynamic value) => value is Timestamp ? value : null;
                        QueryDocumentSnapshot<Map<String, dynamic>>? statForClient(QueryDocumentSnapshot<Map<String, dynamic>> client) {
                          final data = client.data();
                          final authUid = data['authUid']?.toString() ?? '';
                          final email = (data['email'] ?? '').toString().toLowerCase();
                          if (authUid.isNotEmpty && statsByKey.containsKey(authUid)) return statsByKey[authUid];
                          if (statsByKey.containsKey(client.id)) return statsByKey[client.id];
                          if (email.isNotEmpty && statsByKey.containsKey(email)) return statsByKey[email];
                          return null;
                        }
                        final now = DateTime.now();
                        final riskClients = <_ClientRiskEntry>[];
                        for (final client in activeClients) {
                          final data = client.data();
                          final name = data['name']?.toString() ?? 'Cliente';
                          final stat = statForClient(client);
                          final lastWorkout = timestampValue(stat?.data()['lastWorkout']);
                          final reasons = <String>[];
                          var score = 0;
                          final hasRoutine = clientsWithRoutine.contains(client.id);
                          if (!hasRoutine) {
                            reasons.add('Sin rutina');
                            score += 2;
                          }
                          if (lastWorkout == null) {
                            reasons.add('Sin entrenos registrados');
                            score += 3;
                          } else {
                            final days = now.difference(lastWorkout.toDate()).inDays;
                            if (days >= 14) {
                              reasons.add('$days días sin entrenar');
                              score += 3;
                            } else if (days >= 7) {
                              reasons.add('$days días sin entrenar');
                              score += 2;
                            }
                          }
                          if (score > 0) riskClients.add(_ClientRiskEntry(clientId: client.id, name: name, score: score, reasons: reasons, needsRoutine: !hasRoutine));
                        }
                        riskClients.sort((a, b) => b.score.compareTo(a.score));
                        return AppCard(
                          padding: const EdgeInsets.all(18),
                          radius: 30,
                          gradient: context.gymTrainerHeroGradient,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: context.gymFitnessAccent.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: context.gymStrongBorder),
                                    ),
                                    child: Icon(Icons.bolt_rounded, color: context.gymPrimary, size: 28),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(greeting, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, height: 1.0)),
                                        const SizedBox(height: 5),
                                        Text('Resumen rápido de tu gimnasio', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  const spacing = 8.0;
                                  final width = (constraints.maxWidth - spacing) / 2;
                                  return Wrap(spacing: spacing, runSpacing: spacing, children: [
                                    SizedBox(width: width, child: TrainerStatTile(icon: Icons.people, value: activeClients.length.toString(), label: 'Clientes activos', onTap: onOpenClients)),
                                    SizedBox(width: width, child: TrainerStatTile(icon: Icons.fitness_center, value: activeRoutines.length.toString(), label: 'Rutinas activas', onTap: onOpenRoutines)),
                                    SizedBox(width: width, child: TrainerStatTile(icon: Icons.flag, value: pendingGoals.length.toString(), label: 'Objetivos pendientes', onTap: onOpenGoals)),
                                    SizedBox(width: width, child: TrainerStatTile(icon: Icons.groups, value: activeTrainers.toString(), label: 'Entrenadores', onTap: onOpenTrainers)),
                                  ]);
                                },
                              ),
                              const SizedBox(height: 14),
                              _GymHealthBar(value: completion, missingClients: clientsWithoutRoutine.length),
                              const SizedBox(height: 12),
                              _TrainerClientRiskCenter(riskClients: riskClients, onOpenClients: onOpenClients, onOpenRoutineForClient: onOpenRoutineForClient),
                              const SizedBox(height: 12),
                              _NeedsAttentionSection(
                                clientsWithoutRoutine: clientsWithoutRoutine,
                                pendingGoals: pendingGoals,
                                activityStream: activityStream,
                                onOpenClients: onOpenClients,
                                onOpenRoutines: onOpenRoutines,
                                onOpenGoals: onOpenGoals,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ClientRiskEntry {
  final String clientId;
  final String name;
  final int score;
  final List<String> reasons;
  final bool needsRoutine;
  const _ClientRiskEntry({required this.clientId, required this.name, required this.score, required this.reasons, required this.needsRoutine});

  bool get needsFollowUp => reasons.any((reason) => reason.contains('entren'));
  String get recommendedAction => needsRoutine ? 'Asignar rutina' : 'Ver cliente';
  String get actionText => needsRoutine ? 'Crear rutina para este cliente' : 'Revisar seguimiento del cliente';
}

class _TrainerClientRiskCenter extends StatelessWidget {
  final List<_ClientRiskEntry> riskClients;
  final VoidCallback onOpenClients;
  final void Function(String clientId, String clientName) onOpenRoutineForClient;
  const _TrainerClientRiskCenter({required this.riskClients, required this.onOpenClients, required this.onOpenRoutineForClient});

  Color scoreColor(BuildContext context, int score) {
    if (score >= 5) return Colors.redAccent;
    if (score >= 3) return Colors.orangeAccent;
    return context.gymFitnessAccent;
  }

  String scoreLabel(int score) {
    if (score >= 5) return 'Alto';
    if (score >= 3) return 'Medio';
    return 'Bajo';
  }

  void openRecommendedAction(_ClientRiskEntry entry) {
    if (entry.needsRoutine) {
      onOpenRoutineForClient(entry.clientId, entry.name);
    } else {
      onOpenClients();
    }
  }

  @override
  Widget build(BuildContext context) {
    final routineCount = riskClients.where((entry) => entry.needsRoutine).length;
    final followUpCount = riskClients.where((entry) => !entry.needsRoutine).length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.74 : 0.94), borderRadius: BorderRadius.circular(24), border: Border.all(color: context.gymBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.health_and_safety_rounded, color: riskClients.isEmpty ? Colors.green : Colors.orangeAccent, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('Clientes en riesgo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            Text('${riskClients.length}', style: TextStyle(color: riskClients.isEmpty ? Colors.green : Colors.orangeAccent, fontWeight: FontWeight.w900, fontSize: 18)),
          ]),
          const SizedBox(height: 8),
          if (riskClients.isEmpty)
            Text('No hay clientes activos con señales de abandono ahora mismo.', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700))
          else ...[
            Text('$routineCount requieren rutina · $followUpCount requieren seguimiento', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...riskClients.take(6).map((entry) {
              final color = scoreColor(context, entry.score);
              final reasonAndAction = '${entry.reasons.join(' · ')} · ${entry.recommendedAction}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => openRecommendedAction(entry),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(color: context.gymElevatedSurface.withValues(alpha: context.gymIsDark ? 0.70 : 0.82), borderRadius: BorderRadius.circular(18), border: Border.all(color: context.gymBorder)),
                    child: Row(children: [
                      Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)), child: Icon(entry.needsRoutine ? Icons.fitness_center_rounded : Icons.person_search_rounded, color: color, size: 19)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text(reasonAndAction, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ])),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                        child: Text(scoreLabel(entry.score), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                      Icon(Icons.chevron_right_rounded, color: color, size: 22),
                    ]),
                  ),
                ),
              );
            }),
            if (riskClients.length > 6)
              TextButton.icon(onPressed: onOpenClients, icon: const Icon(Icons.list_alt_rounded), label: Text('Ver ${riskClients.length - 6} más')),
          ],
        ],
      ),
    );
  }
}

class _GymHealthBar extends StatelessWidget {
  final double value;
  final int missingClients;
  const _GymHealthBar({required this.value, required this.missingClients});

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    final statusText = missingClients == 0 ? 'Todos los clientes activos tienen rutina' : '$missingClients clientes activos sin rutina';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.74 : 0.92), borderRadius: BorderRadius.circular(22), border: Border.all(color: context.gymBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_rounded, color: context.gymFitnessAccent, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('Estado del gimnasio', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              Text('$percent%', style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: value,
              backgroundColor: context.gymProgressTrack,
              valueColor: AlwaysStoppedAnimation<Color>(context.gymFitnessAccent),
            ),
          ),
          const SizedBox(height: 8),
          Text(statusText, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _NeedsAttentionSection extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> clientsWithoutRoutine;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> pendingGoals;
  final Stream<QuerySnapshot<Map<String, dynamic>>> activityStream;
  final VoidCallback onOpenClients;
  final VoidCallback onOpenRoutines;
  final VoidCallback onOpenGoals;

  const _NeedsAttentionSection({required this.clientsWithoutRoutine, required this.pendingGoals, required this.activityStream, required this.onOpenClients, required this.onOpenRoutines, required this.onOpenGoals});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(Icons.tips_and_updates_rounded, color: context.gymPrimary, size: 20), const SizedBox(width: 8), const Text('Qué revisar hoy', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 10),
        if (clientsWithoutRoutine.isEmpty && pendingGoals.isEmpty)
          _AttentionItem(
            icon: Icons.check_circle_rounded,
            color: Colors.green,
            title: 'Todo está bajo control',
            subtitle: 'No hay avisos importantes ahora mismo.',
            onTap: onOpenClients,
          )
        else ...[
          if (clientsWithoutRoutine.isNotEmpty)
            _AttentionItem(
              icon: Icons.assignment_late_rounded,
              color: Colors.orangeAccent,
              title: '${clientsWithoutRoutine.length} clientes sin rutina',
              subtitle: _clientNames(clientsWithoutRoutine),
              onTap: onOpenRoutines,
            ),
          if (pendingGoals.isNotEmpty)
            _AttentionItem(
              icon: Icons.flag_rounded,
              color: context.gymPrimary,
              title: '${pendingGoals.length} objetivos pendientes',
              subtitle: 'Revisa objetivos abiertos y próximos avances.',
              onTap: onOpenGoals,
            ),
        ],
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: activityStream,
          builder: (context, snapshot) {
            final recent = snapshot.data?.docs.length ?? 0;
            return _AttentionItem(
              icon: Icons.history_rounded,
              color: context.gymFitnessAccent,
              title: '$recent movimientos recientes',
              subtitle: 'Últimas actualizaciones registradas en el gimnasio.',
              onTap: null,
            );
          },
        ),
      ],
    );
  }

  String _clientNames(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final names = docs.take(3).map((doc) => (doc.data()['name'] ?? 'Cliente').toString()).toList();
    if (docs.length > 3) names.add('+${docs.length - 3} más');
    return names.join(' · ');
  }
}

class _AttentionItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _AttentionItem({required this.icon, required this.color, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.gymBorder)),
            child: Row(
              children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: color, size: 21)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
                if (onTap != null) Icon(Icons.chevron_right_rounded, color: context.gymMutedText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

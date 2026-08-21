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
                        final completion = activeClients.isEmpty ? 0.0 : (clientsWithRoutine.length / activeClients.length).clamp(0.0, 1.0).toDouble();

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
                          if (score > 0) {
                            riskClients.add(_ClientRiskEntry(clientId: client.id, name: name, score: score, reasons: reasons, needsRoutine: !hasRoutine));
                          }
                        }
                        riskClients.sort((a, b) => b.score.compareTo(a.score));

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TrainerClientRiskCenter(
                              riskClients: riskClients,
                              onOpenClients: onOpenClients,
                              onOpenRoutineForClient: onOpenRoutineForClient,
                            ),
                            const SizedBox(height: 12),
                            _GymHealthBar(value: completion, missingClients: clientsWithoutRoutine.length),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  _TrainerMetricChip(icon: Icons.people_rounded, value: activeClients.length.toString(), label: 'Clientes', onTap: onOpenClients),
                                  _TrainerMetricChip(icon: Icons.fitness_center_rounded, value: activeRoutines.length.toString(), label: 'Rutinas', onTap: onOpenRoutines),
                                  _TrainerMetricChip(icon: Icons.flag_rounded, value: pendingGoals.length.toString(), label: 'Objetivos', onTap: onOpenGoals),
                                  _TrainerMetricChip(icon: Icons.groups_rounded, value: activeTrainers.toString(), label: 'Equipo', onTap: onOpenTrainers),
                                ],
                              ),
                            ),
                          ],
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

class _TrainerMetricChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  const _TrainerMetricChip({required this.icon, required this.value, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.44 : 0.66),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.11), shape: BoxShape.circle),
                  child: Icon(icon, color: context.gymPrimary, size: 17),
                ),
                const SizedBox(width: 8),
                Text(value, style: TextStyle(color: context.gymText, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactHealthBadge extends StatelessWidget {
  final double value;

  const _CompactHealthBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
      child: Text('$percent%', style: TextStyle(color: context.gymPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
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
    if (riskClients.isEmpty) {
      return _FlatInfoRow(icon: Icons.check_circle_rounded, color: Colors.green, title: 'Prioridades de hoy', subtitle: 'No hay acciones urgentes ahora mismo.', value: '0', onTap: onOpenClients);
    }

    final routineCount = riskClients.where((entry) => entry.needsRoutine).length;
    final followUpCount = riskClients.where((entry) => !entry.needsRoutine).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(child: Text('Prioridades de hoy', style: TextStyle(color: context.gymText, fontSize: 17, fontWeight: FontWeight.w900))),
              Text('${riskClients.length}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 17, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('$routineCount requieren rutina · $followUpCount requieren seguimiento', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...riskClients.take(3).map((entry) {
          final color = scoreColor(context, entry.score);
          return _RiskClientRow(entry: entry, color: color, scoreLabel: scoreLabel(entry.score), onTap: () => openRecommendedAction(entry));
        }),
        if (riskClients.length > 3) TextButton.icon(onPressed: onOpenClients, icon: const Icon(Icons.list_alt_rounded), label: Text('Ver ${riskClients.length - 3} más')),
      ],
    );
  }
}

class _RiskClientRow extends StatelessWidget {
  final _ClientRiskEntry entry;
  final Color color;
  final String scoreLabel;
  final VoidCallback onTap;

  const _RiskClientRow({required this.entry, required this.color, required this.scoreLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)), child: Icon(entry.needsRoutine ? Icons.fitness_center_rounded : Icons.person_search_rounded, color: color, size: 19)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text('${entry.reasons.join(' · ')} · ${entry.recommendedAction}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: 8),
                Text(scoreLabel, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
                Icon(Icons.chevron_right_rounded, color: color, size: 22),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.health_and_safety_rounded, color: context.gymFitnessAccent, size: 19),
            const SizedBox(width: 8),
            Expanded(child: Text('Estado del gimnasio', style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900, fontSize: 15.5))),
            Text('$percent%', style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
          ]),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(minHeight: 8, value: value, backgroundColor: context.gymProgressTrack, valueColor: AlwaysStoppedAnimation<Color>(context.gymFitnessAccent)),
          ),
          const SizedBox(height: 7),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [Icon(Icons.tips_and_updates_rounded, color: context.gymPrimary, size: 19), const SizedBox(width: 8), Text('Qué revisar hoy', style: TextStyle(color: context.gymText, fontSize: 17, fontWeight: FontWeight.w900))]),
      ),
      const SizedBox(height: 8),
      if (clientsWithoutRoutine.isEmpty && pendingGoals.isEmpty)
        _FlatInfoRow(icon: Icons.check_circle_rounded, color: Colors.green, title: 'Todo bajo control', subtitle: 'No hay avisos importantes ahora mismo.', value: '', onTap: onOpenClients)
      else ...[
        if (clientsWithoutRoutine.isNotEmpty)
          _FlatInfoRow(icon: Icons.assignment_late_rounded, color: Colors.orangeAccent, title: '${clientsWithoutRoutine.length} clientes sin rutina', subtitle: _clientNames(clientsWithoutRoutine), value: '', onTap: onOpenRoutines),
        if (pendingGoals.isNotEmpty)
          _FlatInfoRow(icon: Icons.flag_rounded, color: context.gymPrimary, title: '${pendingGoals.length} objetivos pendientes', subtitle: 'Revisa objetivos abiertos y próximos avances.', value: '', onTap: onOpenGoals),
      ],
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: activityStream,
        builder: (context, snapshot) {
          final recent = snapshot.data?.docs.length ?? 0;
          return _FlatInfoRow(icon: Icons.history_rounded, color: context.gymFitnessAccent, title: '$recent movimientos recientes', subtitle: 'Disponible en la actividad del gimnasio.', value: '', onTap: null);
        },
      ),
    ]);
  }

  String _clientNames(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final names = docs.take(3).map((doc) => (doc.data()['name'] ?? 'Cliente').toString()).toList();
    if (docs.length > 3) names.add('+${docs.length - 3} más');
    return names.join(' · ');
  }
}

class _FlatInfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback? onTap;

  const _FlatInfoRow({required this.icon, required this.color, required this.title, required this.subtitle, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 19)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ])),
              if (value.isNotEmpty) Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
              if (onTap != null) Icon(Icons.chevron_right_rounded, color: color, size: 22),
            ]),
          ),
        ),
      ),
    );
  }
}

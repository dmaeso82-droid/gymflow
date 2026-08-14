part of '../user_home_page.dart';

class _OnboardingChecklistCard extends StatefulWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenPhotos;
  final VoidCallback onOpenRoutines;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenChallenges;
  final VoidCallback onOpenRecords;

  const _OnboardingChecklistCard({
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.onOpenProfile,
    required this.onOpenPhotos,
    required this.onOpenRoutines,
    required this.onOpenGoals,
    required this.onOpenChallenges,
    required this.onOpenRecords,
  });

  @override
  State<_OnboardingChecklistCard> createState() => _OnboardingChecklistCardState();
}

class _OnboardingChecklistCardState extends State<_OnboardingChecklistCard> {
  late Future<_OnboardingData> onboardingFuture;
  bool expanded = false;

  @override
  void initState() {
    super.initState();
    onboardingFuture = loadOnboardingData();
  }

  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  String get normalizedEmail => widget.userEmail.trim().toLowerCase();

  String get userKey {
    if (widget.userId.trim().isNotEmpty) return widget.userId.trim();
    return normalizedEmail.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  DocumentReference<Map<String, dynamic>> get statsRef => firestore.collection('gyms').doc(widget.gymId).collection('user_stats').doc(userKey);

  DocumentReference<Map<String, dynamic>> get onboardingAchievementRef => firestore.collection('gyms').doc(widget.gymId).collection('user_achievements').doc('${userKey}_onboarding_first_steps');

  CollectionReference<Map<String, dynamic>> get photosRef => firestore.collection('gyms').doc(widget.gymId).collection('progress_photos');

  CollectionReference<Map<String, dynamic>> get logsRef => firestore.collection('gyms').doc(widget.gymId).collection('workout_logs');

  CollectionReference<Map<String, dynamic>> get pointsLedgerRef => firestore.collection('gyms').doc(widget.gymId).collection('points_ledger');

  int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double doubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse((value?.toString() ?? '').replaceAll(',', '.')) ?? 0.0;
  }

  bool hasUsefulName() {
    final cleanName = widget.userName.trim().toLowerCase();
    return cleanName.isNotEmpty && cleanName != 'usuario' && cleanName != 'cliente';
  }

  Future<int> loadPhotoCount() async {
    final docsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    if (widget.userId.trim().isNotEmpty) {
      final byUser = await photosRef.where('userId', isEqualTo: widget.userId.trim()).limit(3).get();
      for (final doc in byUser.docs) {
        docsById[doc.id] = doc;
      }
    }
    if (normalizedEmail.isNotEmpty) {
      final byEmail = await photosRef.where('userEmail', isEqualTo: normalizedEmail).limit(3).get();
      for (final doc in byEmail.docs) {
        docsById[doc.id] = doc;
      }
    }
    return docsById.length;
  }

  Future<int> loadRecordCount() async {
    final docsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    if (widget.userId.trim().isNotEmpty) {
      final byUser = await logsRef.where('userId', isEqualTo: widget.userId.trim()).limit(60).get();
      for (final doc in byUser.docs) {
        docsById[doc.id] = doc;
      }
    }
    if (normalizedEmail.isNotEmpty) {
      final byEmail = await logsRef.where('userEmail', isEqualTo: normalizedEmail).limit(60).get();
      for (final doc in byEmail.docs) {
        docsById[doc.id] = doc;
      }
    }
    final exercises = <String>{};
    for (final doc in docsById.values) {
      final data = doc.data();
      final exercise = data['exercise']?.toString().trim() ?? '';
      if (exercise.isEmpty) continue;
      final weight = doubleValue(data['weight']);
      final reps = intValue(data['reps']);
      if (weight > 0 || reps > 0) exercises.add(exercise);
    }
    return exercises.length;
  }

  Future<bool> loadChallengeCompleted() async {
    final docsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    final byUser = widget.userId.trim().isNotEmpty
        ? await pointsLedgerRef.where('userId', isEqualTo: widget.userId.trim()).limit(80).get()
        : null;
    if (byUser != null) {
      for (final doc in byUser.docs) {
        docsById[doc.id] = doc;
      }
    }
    final byEmail = normalizedEmail.isNotEmpty
        ? await pointsLedgerRef.where('userEmail', isEqualTo: normalizedEmail).limit(80).get()
        : null;
    if (byEmail != null) {
      for (final doc in byEmail.docs) {
        docsById[doc.id] = doc;
      }
    }
    for (final doc in docsById.values) {
      final data = doc.data();
      final sourceType = data['sourceType']?.toString().toLowerCase() ?? '';
      final sourceId = data['sourceId']?.toString().toLowerCase() ?? '';
      if (sourceType.contains('challenge') || sourceId.contains('challenge')) return true;
    }
    return false;
  }

  Future<void> unlockOnboardingAchievement({required int completedSteps, required int totalSteps}) async {
    if (userKey.isEmpty) return;
    final existing = await onboardingAchievementRef.get();
    if (existing.exists) return;
    final metadata = {
      'achievementId': 'onboarding_first_steps',
      'title': 'Primeros pasos',
      'description': 'Completa los primeros pasos de GymFlow en DalaiGym.',
      'metric': 'onboarding',
      'target': totalSteps,
      'current': completedSteps,
      'iconKey': 'rocket',
    };
    await onboardingAchievementRef.set({
      ...metadata,
      'userId': widget.userId,
      'userName': widget.userName,
      'userEmail': normalizedEmail,
      'unlockedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await PointsService(gymId: widget.gymId).awardPoints(
      userId: widget.userId,
      userName: widget.userName,
      userEmail: normalizedEmail,
      points: 250,
      sourceType: 'onboarding_completed',
      sourceId: 'first_steps',
      metadata: metadata,
    );
  }

  Future<_OnboardingData> loadOnboardingData() async {
    final statsSnapshot = await statsRef.get();
    final stats = statsSnapshot.data() ?? {};
    final workouts = intValue(stats['workouts']);
    final currentStreak = intValue(stats['currentStreak']);
    final photoCount = await loadPhotoCount();
    final recordCount = await loadRecordCount();
    final challengeCompleted = await loadChallengeCompleted();
    final wasAlreadyUnlocked = (await onboardingAchievementRef.get()).exists;

    final steps = [
      _OnboardingStep(
        icon: Icons.person_rounded,
        title: 'Completa tu perfil',
        subtitle: 'Añade tus datos básicos para que el entrenador tenga todo ordenado.',
        completed: hasUsefulName() && normalizedEmail.isNotEmpty,
        actionLabel: 'Editar perfil',
        onTap: widget.onOpenProfile,
      ),
      _OnboardingStep(
        icon: Icons.photo_camera_rounded,
        title: 'Sube tu primera foto',
        subtitle: photoCount > 0 ? 'Ya tienes $photoCount foto${photoCount == 1 ? '' : 's'} de progreso.' : 'Guarda tu punto de partida físico para comparar más adelante.',
        completed: photoCount > 0,
        actionLabel: 'Subir foto',
        onTap: widget.onOpenPhotos,
      ),
      _OnboardingStep(
        icon: Icons.fitness_center_rounded,
        title: 'Completa tu primer entreno',
        subtitle: workouts > 0 ? 'Ya llevas $workouts entreno${workouts == 1 ? '' : 's'} registrado${workouts == 1 ? '' : 's'}.' : 'Empieza por tu rutina semanal y registra tu primera sesión.',
        completed: workouts > 0,
        actionLabel: 'Ir a rutinas',
        onTap: widget.onOpenRoutines,
      ),
      _OnboardingStep(
        icon: Icons.local_fire_department_rounded,
        title: 'Consigue una racha de 3 días',
        subtitle: currentStreak >= 3 ? 'Racha activa de $currentStreak día${currentStreak == 1 ? '' : 's'}.' : 'Entrena varios días de apertura seguidos para crear hábito.',
        completed: currentStreak >= 3,
        actionLabel: 'Ver objetivos',
        onTap: widget.onOpenGoals,
      ),
      _OnboardingStep(
        icon: Icons.emoji_events_rounded,
        title: 'Completa tu primer reto',
        subtitle: challengeCompleted ? 'Ya has completado al menos un reto.' : 'Participa en retos para sumar puntos y competir con otros clientes.',
        completed: challengeCompleted,
        actionLabel: 'Ver retos',
        onTap: widget.onOpenChallenges,
      ),
      _OnboardingStep(
        icon: Icons.workspace_premium_rounded,
        title: 'Consigue tu primer récord personal',
        subtitle: recordCount > 0 ? 'Ya tienes marcas registradas en $recordCount ejercicio${recordCount == 1 ? '' : 's'}.' : 'Registra peso y repeticiones para crear tus primeras marcas.',
        completed: recordCount > 0,
        actionLabel: 'Ver récords',
        onTap: widget.onOpenRecords,
      ),
    ];
    final completedSteps = steps.where((step) => step.completed).length;
    if (completedSteps == steps.length && !wasAlreadyUnlocked) {
      await unlockOnboardingAchievement(completedSteps: completedSteps, totalSteps: steps.length);
      return _OnboardingData(steps: steps, newlyUnlocked: true, alreadyUnlocked: true);
    }
    return _OnboardingData(steps: steps, newlyUnlocked: false, alreadyUnlocked: wasAlreadyUnlocked);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_OnboardingData>(
      future: onboardingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppCard(
            child: Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Expanded(child: Text('Preparando tus primeros pasos...', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w800))),
              ],
            ),
          );
        }
        final data = snapshot.data ?? _OnboardingData.empty(
          onOpenProfile: widget.onOpenProfile,
          onOpenPhotos: widget.onOpenPhotos,
          onOpenRoutines: widget.onOpenRoutines,
          onOpenGoals: widget.onOpenGoals,
          onOpenChallenges: widget.onOpenChallenges,
          onOpenRecords: widget.onOpenRecords,
        );
        final steps = data.steps;
        final completed = steps.where((step) => step.completed).length;
        final progress = steps.isEmpty ? 0.0 : completed / steps.length;
        final nextPendingStep = steps.firstWhere(
          (step) => !step.completed,
          orElse: () => steps.first,
        );

        if (completed == steps.length) {
          return AppCard(
            gradient: context.gymHeroGradient,
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: const Icon(Icons.verified_rounded, color: Colors.greenAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.newlyUnlocked ? 'Logro desbloqueado: Primeros pasos' : 'Inicio completado', style: TextStyle(color: context.gymText, fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(data.newlyUnlocked ? 'Has completado el programa de inicio y has ganado +250 puntos.' : 'Ya tienes lo básico listo para sacarle partido a GymFlow.', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.gymPrimary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.rocket_launch_rounded, color: context.gymPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bienvenido a DalaiGym', style: TextStyle(color: context.gymText, fontSize: 19, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('$completed de ${steps.length} primeros pasos completados', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  Text('${(progress * 100).round()}%', style: TextStyle(color: context.gymPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: progress,
                  backgroundColor: context.gymBorder.withValues(alpha: 0.42),
                  valueColor: AlwaysStoppedAnimation<Color>(context.gymPrimary),
                ),
              ),
              const SizedBox(height: 12),
              if (expanded) ...[
                ...steps.map((step) => _OnboardingStepTile(step: step)),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        expanded = false;
                      });
                    },
                    icon: const Icon(Icons.expand_less_rounded),
                    label: const Text('Ocultar plan completo'),
                  ),
                ),
              ] else ...[
                _CurrentMissionCard(
                  step: nextPendingStep,
                  completed: completed,
                  total: steps.length,
                  onShowFullPlan: () {
                    setState(() {
                      expanded = true;
                    });
                  },
                ),
              ],
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: context.gymPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: context.gymPrimary.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.card_giftcard_rounded, size: 16, color: context.gymPrimary),
                      const SizedBox(width: 6),
                      Text('Recompensa final: +250 pts', style: TextStyle(color: context.gymPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _CurrentMissionCard extends StatelessWidget {
  final _OnboardingStep step;
  final int completed;
  final int total;
  final VoidCallback onShowFullPlan;

  const _CurrentMissionCard({
    required this.step,
    required this.completed,
    required this.total,
    required this.onShowFullPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.gymPrimary.withValues(alpha: context.gymIsDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.gymPrimary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.gymPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(step.icon, color: context.gymPrimary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tu siguiente misión', style: TextStyle(color: context.gymPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(step.title, style: TextStyle(color: context.gymText, fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Text('$completed/$total', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          Text(step.subtitle, style: TextStyle(color: context.gymMutedText, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: step.onTap,
              icon: Icon(step.icon, size: 18),
              label: Text(step.actionLabel.toUpperCase()),
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: onShowFullPlan,
              icon: const Icon(Icons.expand_more_rounded),
              label: const Text('Ver plan completo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingData {
  final List<_OnboardingStep> steps;
  final bool newlyUnlocked;
  final bool alreadyUnlocked;

  const _OnboardingData({required this.steps, required this.newlyUnlocked, required this.alreadyUnlocked});

  factory _OnboardingData.empty({
    required VoidCallback onOpenProfile,
    required VoidCallback onOpenPhotos,
    required VoidCallback onOpenRoutines,
    required VoidCallback onOpenGoals,
    required VoidCallback onOpenChallenges,
    required VoidCallback onOpenRecords,
  }) {
    return _OnboardingData(
      newlyUnlocked: false,
      alreadyUnlocked: false,
      steps: [
        _OnboardingStep(icon: Icons.person_rounded, title: 'Completa tu perfil', subtitle: 'Añade tus datos básicos.', completed: false, actionLabel: 'Editar perfil', onTap: onOpenProfile),
        _OnboardingStep(icon: Icons.photo_camera_rounded, title: 'Sube tu primera foto', subtitle: 'Guarda tu punto de partida físico.', completed: false, actionLabel: 'Subir foto', onTap: onOpenPhotos),
        _OnboardingStep(icon: Icons.fitness_center_rounded, title: 'Completa tu primer entreno', subtitle: 'Registra tu primera sesión.', completed: false, actionLabel: 'Ir a rutinas', onTap: onOpenRoutines),
        _OnboardingStep(icon: Icons.local_fire_department_rounded, title: 'Consigue una racha de 3 días', subtitle: 'Entrena varios días de apertura seguidos.', completed: false, actionLabel: 'Ver objetivos', onTap: onOpenGoals),
        _OnboardingStep(icon: Icons.emoji_events_rounded, title: 'Completa tu primer reto', subtitle: 'Participa en retos para sumar puntos.', completed: false, actionLabel: 'Ver retos', onTap: onOpenChallenges),
        _OnboardingStep(icon: Icons.workspace_premium_rounded, title: 'Consigue tu primer récord personal', subtitle: 'Registra peso y repeticiones.', completed: false, actionLabel: 'Ver récords', onTap: onOpenRecords),
      ],
    );
  }
}

class _OnboardingStep {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool completed;
  final String actionLabel;
  final VoidCallback onTap;

  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.completed,
    required this.actionLabel,
    required this.onTap,
  });
}

class _OnboardingStepTile extends StatelessWidget {
  final _OnboardingStep step;

  const _OnboardingStepTile({required this.step});

  @override
  Widget build(BuildContext context) {
    final iconColor = step.completed ? Colors.greenAccent : context.gymPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: step.completed ? null : step.onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: step.completed ? Colors.greenAccent.withValues(alpha: 0.09) : context.gymSubtleSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: step.completed ? Colors.greenAccent.withValues(alpha: 0.22) : context.gymBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(step.completed ? Icons.check_rounded : step.icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.title, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(step.subtitle, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (step.completed)
                Icon(Icons.done_all_rounded, color: Colors.greenAccent)
              else
                Text(step.actionLabel, style: TextStyle(color: context.gymPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

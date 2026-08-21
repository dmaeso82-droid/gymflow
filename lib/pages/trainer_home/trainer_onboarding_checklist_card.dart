part of '../trainer_home_page.dart';

class _TrainerOnboardingChecklistCard extends StatefulWidget {
  final String gymId;
  final String trainerName;
  final VoidCallback onOpenClients;
  final VoidCallback onOpenRoutines;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenProgress;
  final VoidCallback onOpenTraining;

  const _TrainerOnboardingChecklistCard({
    required this.gymId,
    required this.trainerName,
    required this.onOpenClients,
    required this.onOpenRoutines,
    required this.onOpenGoals,
    required this.onOpenProgress,
    required this.onOpenTraining,
  });

  @override
  State<_TrainerOnboardingChecklistCard> createState() => _TrainerOnboardingChecklistCardState();
}

class _TrainerOnboardingChecklistCardState extends State<_TrainerOnboardingChecklistCard> {
  late Future<_TrainerOnboardingData> onboardingFuture;
  bool expanded = false;

  @override
  void initState() {
    super.initState();
    onboardingFuture = loadOnboardingData();
  }

  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> gymCollection(String name) {
    return firestore.collection('gyms').doc(widget.gymId).collection(name);
  }

  Future<int> countCollection(String name) async {
    try {
      final snapshot = await gymCollection(name).limit(4).get();
      return snapshot.size;
    } catch (_) {
      return 0;
    }
  }

  DocumentReference<Map<String, dynamic>> get gymRef =>
      firestore.collection('gyms').doc(widget.gymId);

  Future<void> persistOnboarding({
    required bool ownerProfile,
    required bool firstTrainer,
    required bool firstClient,
    required bool firstRoutine,
    required bool firstGoal,
  }) async {
    final completed = ownerProfile && firstTrainer && firstClient && firstRoutine && firstGoal;
    try {
      await gymRef.set({
        'onboarding': {
          'completed': completed,
          'ownerProfile': ownerProfile,
          'firstTrainer': firstTrainer,
          'firstClient': firstClient,
          'firstRoutine': firstRoutine,
          'firstGoal': firstGoal,
          'updatedAt': FieldValue.serverTimestamp(),
          if (completed) 'completedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<_TrainerOnboardingData> loadOnboardingData() async {
    final gymSnapshot = await gymRef.get();
    final gymData = gymSnapshot.data() ?? <String, dynamic>{};
    final gymName = gymData['name']?.toString().trim() ?? '';
    final ownerName = gymData['ownerName']?.toString().trim() ?? '';
    final ownerEmail = gymData['ownerEmail']?.toString().trim() ?? '';
    final counts = await Future.wait<int>([
      countCollection('trainers'),
      countCollection('clients'),
      countCollection('routines'),
      countCollection('goals'),
    ]);
    final trainers = counts[0];
    final clients = counts[1];
    final routines = counts[2];
    final goals = counts[3];
    final ownerProfile = gymName.isNotEmpty && ownerName.isNotEmpty && ownerEmail.isNotEmpty;
    final firstTrainer = trainers > 1;
    final firstClient = clients > 0;
    final firstRoutine = routines > 0;
    final firstGoal = goals > 0;
    await persistOnboarding(
      ownerProfile: ownerProfile,
      firstTrainer: firstTrainer,
      firstClient: firstClient,
      firstRoutine: firstRoutine,
      firstGoal: firstGoal,
    );
    final steps = [
      _TrainerOnboardingStep(
        icon: Icons.storefront_rounded,
        title: 'Completa el perfil del gimnasio',
        subtitle: ownerProfile ? '$gymName ya tiene propietario y email configurados.' : 'Completa nombre, propietario y email del gimnasio.',
        completed: ownerProfile,
        actionLabel: 'Perfil',
        onTap: null,
      ),
      _TrainerOnboardingStep(
        icon: Icons.badge_rounded,
        title: 'Añade tu primer entrenador',
        subtitle: firstTrainer ? 'Ya hay un entrenador adicional junto al propietario.' : 'Abre Equipo en las herramientas y añade un entrenador.',
        completed: firstTrainer,
        actionLabel: 'Equipo',
        onTap: null,
      ),
      _TrainerOnboardingStep(
        icon: Icons.people_rounded,
        title: 'Crea tu primer cliente',
        subtitle: firstClient ? 'Ya tienes $clients cliente${clients == 1 ? '' : 's'} registrado${clients == 1 ? '' : 's'}.' : 'Añade un cliente para empezar a trabajar con GymFlow.',
        completed: firstClient,
        actionLabel: 'Clientes',
        onTap: widget.onOpenClients,
      ),
      _TrainerOnboardingStep(
        icon: Icons.fitness_center_rounded,
        title: 'Asigna la primera rutina',
        subtitle: firstRoutine ? 'Ya existe al menos una rutina en el gimnasio.' : 'Prepara el primer entrenamiento para un cliente.',
        completed: firstRoutine,
        actionLabel: 'Rutinas',
        onTap: widget.onOpenRoutines,
      ),
      _TrainerOnboardingStep(
        icon: Icons.flag_rounded,
        title: 'Crea el primer objetivo',
        subtitle: firstGoal ? 'Ya existe al menos un objetivo de seguimiento.' : 'Define una meta para medir la evolución del cliente.',
        completed: firstGoal,
        actionLabel: 'Objetivos',
        onTap: widget.onOpenGoals,
      ),
    ];
    return _TrainerOnboardingData(steps: steps);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TrainerOnboardingData>(
      future: onboardingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: context.gymPrimary)),
                const SizedBox(width: 12),
                Expanded(child: Text('Preparando el onboarding del gimnasio...', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w800))),
              ],
            ),
          );
        }

        final data = snapshot.data ?? const _TrainerOnboardingData(steps: []);
        if (data.steps.isEmpty) return const SizedBox.shrink();
        final completed = data.steps.where((step) => step.completed).length;
        final progress = completed / data.steps.length;

        if (progress >= 1.0) return const SizedBox.shrink();

        final nextStep = data.steps.firstWhere((step) => !step.completed, orElse: () => data.steps.first);

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(17)),
                    child: Icon(Icons.school_rounded, color: context.gymPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Pon en marcha tu gimnasio', style: TextStyle(color: context.gymText, fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text('$completed de ${data.steps.length} completados', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  Text('${(progress * 100).round()}%', style: TextStyle(color: context.gymPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: progress,
                  backgroundColor: context.gymProgressTrack,
                  valueColor: AlwaysStoppedAnimation<Color>(context.gymPrimary),
                ),
              ),
              const SizedBox(height: 10),
              _TrainerCurrentMissionStrip(
                step: nextStep,
                completed: completed,
                total: data.steps.length,
                expanded: expanded,
                onShowFullPlan: () => setState(() => expanded = !expanded),
              ),
              if (expanded) ...[
                const SizedBox(height: 10),
                ...data.steps.map((step) => _TrainerOnboardingStepTile(step: step)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TrainerCurrentMissionStrip extends StatelessWidget {
  final _TrainerOnboardingStep step;
  final int completed;
  final int total;
  final bool expanded;
  final VoidCallback onShowFullPlan;

  const _TrainerCurrentMissionStrip({required this.step, required this.completed, required this.total, required this.expanded, required this.onShowFullPlan});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(15)),
          child: Icon(step.icon, color: context.gymPrimary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(step.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontSize: 14.5, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(step.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        if (step.onTap != null) TextButton(onPressed: step.onTap, child: Text(step.actionLabel.toUpperCase())),
        IconButton(
          tooltip: expanded ? 'Ocultar plan' : 'Ver plan completo',
          onPressed: onShowFullPlan,
          icon: Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
        ),
      ],
    );
  }
}

class _TrainerOnboardingData {
  final List<_TrainerOnboardingStep> steps;

  const _TrainerOnboardingData({required this.steps});
}

class _TrainerOnboardingStep {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool completed;
  final String actionLabel;
  final VoidCallback? onTap;

  const _TrainerOnboardingStep({required this.icon, required this.title, required this.subtitle, required this.completed, required this.actionLabel, required this.onTap});
}

class _TrainerOnboardingStepTile extends StatelessWidget {
  final _TrainerOnboardingStep step;

  const _TrainerOnboardingStepTile({required this.step});

  @override
  Widget build(BuildContext context) {
    final iconColor = step.completed ? Colors.greenAccent : context.gymPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: step.completed ? null : step.onTap,
          child: Ink(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: step.completed ? Colors.greenAccent.withValues(alpha: 0.08) : context.gymElevatedSurface.withValues(alpha: 0.50), borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)), child: Icon(step.completed ? Icons.check_rounded : step.icon, color: iconColor, size: 21)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(step.title, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(step.subtitle, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                ])),
                if (step.completed) const Icon(Icons.done_all_rounded, color: Colors.greenAccent) else Text(step.actionLabel, style: TextStyle(color: context.gymPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

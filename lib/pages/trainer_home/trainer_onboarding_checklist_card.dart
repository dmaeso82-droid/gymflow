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

  Future<bool> hasProgressData() async {
    final measurements = await countCollection('measurements');
    if (measurements > 0) return true;
    final photos = await countCollection('progress_photos');
    return photos > 0;
  }

  Future<bool> trainerAthleteModeReady() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final clientDoc = await gymCollection('clients').doc(user.uid).get();
      final data = clientDoc.data() ?? {};
      return clientDoc.exists && data['isTrainerClient'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<_TrainerOnboardingData> loadOnboardingData() async {
    final clients = await countCollection('clients');
    final routines = await countCollection('routines');
    final goals = await countCollection('goals');
    final progressReady = await hasProgressData();
    final athleteModeReady = await trainerAthleteModeReady();
    final activity = await countCollection('activity');

    final steps = [
      _TrainerOnboardingStep(
        icon: Icons.people_rounded,
        title: 'Crea tu primer cliente',
        subtitle: clients > 0 ? 'Ya tienes $clients cliente${clients == 1 ? '' : 's'} registrado${clients == 1 ? '' : 's'}.' : 'Añade clientes para empezar a gestionar rutinas y seguimiento.',
        completed: clients > 0,
        actionLabel: 'Clientes',
        onTap: widget.onOpenClients,
      ),
      _TrainerOnboardingStep(
        icon: Icons.fitness_center_rounded,
        title: 'Asigna una rutina',
        subtitle: routines > 0 ? 'Ya hay rutinas activas o creadas en el gimnasio.' : 'Prepara entrenamientos para que el cliente sepa qué hacer.',
        completed: routines > 0,
        actionLabel: 'Rutinas',
        onTap: widget.onOpenRoutines,
      ),
      _TrainerOnboardingStep(
        icon: Icons.flag_rounded,
        title: 'Crea un objetivo',
        subtitle: goals > 0 ? 'Ya existen objetivos de seguimiento.' : 'Marca metas claras para mejorar la adherencia del cliente.',
        completed: goals > 0,
        actionLabel: 'Objetivos',
        onTap: widget.onOpenGoals,
      ),
      _TrainerOnboardingStep(
        icon: Icons.insights_rounded,
        title: 'Revisa el progreso',
        subtitle: progressReady ? 'Ya tienes datos de progreso físico o medidas.' : 'Consulta fotos, medidas y evolución para tener contexto real.',
        completed: progressReady,
        actionLabel: 'Progreso',
        onTap: widget.onOpenProgress,
      ),
      _TrainerOnboardingStep(
        icon: Icons.self_improvement_rounded,
        title: 'Usa tu modo atleta',
        subtitle: athleteModeReady ? 'Tu perfil de entrenador también funciona como atleta.' : 'Prueba GymFlow como cliente para entender la experiencia completa.',
        completed: athleteModeReady,
        actionLabel: 'Mi entreno',
        onTap: widget.onOpenTraining,
      ),
      _TrainerOnboardingStep(
        icon: Icons.bolt_rounded,
        title: 'Explora el panel completo',
        subtitle: activity > 0 ? 'Ya hay actividad registrada en el gimnasio.' : 'Revisa alertas, accesos inteligentes y actividad reciente.',
        completed: activity > 0,
        actionLabel: 'Ver panel',
        onTap: () {},
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
          return AppCard(
            child: Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: context.gymPrimary)),
                const SizedBox(width: 12),
                Expanded(child: Text('Preparando la guía del entrenador...', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w800))),
              ],
            ),
          );
        }

        final data = snapshot.data ?? const _TrainerOnboardingData(steps: []);
        if (data.steps.isEmpty) return const SizedBox.shrink();
        final completed = data.steps.where((step) => step.completed).length;
        final progress = completed / data.steps.length;
        final nextStep = data.steps.firstWhere((step) => !step.completed, orElse: () => data.steps.first);

        if (completed == data.steps.length) {
          return AppCard(
            gradient: context.gymTrainerHeroGradient,
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
                      Text('Entrenador preparado', style: TextStyle(color: context.gymText, fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('Ya tienes lo esencial listo para gestionar clientes, rutinas y progreso.', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return AppCard(
          padding: const EdgeInsets.all(16),
          radius: 24,
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
                    child: Icon(Icons.school_rounded, color: context.gymPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bienvenido entrenador', style: TextStyle(color: context.gymText, fontSize: 19, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('$completed de ${data.steps.length} primeros pasos completados', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w800)),
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
                ...data.steps.map((step) => _TrainerOnboardingStepTile(step: step)),
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => expanded = false),
                    icon: const Icon(Icons.expand_less_rounded),
                    label: const Text('Ocultar plan completo'),
                  ),
                ),
              ] else ...[
                _TrainerCurrentMissionCard(
                  step: nextStep,
                  completed: completed,
                  total: data.steps.length,
                  onShowFullPlan: () => setState(() => expanded = true),
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
                      Icon(Icons.workspace_premium_rounded, size: 16, color: context.gymPrimary),
                      const SizedBox(width: 6),
                      Text('Objetivo: entrenador preparado', style: TextStyle(color: context.gymPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
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

class _TrainerCurrentMissionCard extends StatelessWidget {
  final _TrainerOnboardingStep step;
  final int completed;
  final int total;
  final VoidCallback onShowFullPlan;

  const _TrainerCurrentMissionCard({required this.step, required this.completed, required this.total, required this.onShowFullPlan});

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
                decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
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
          if (step.onTap != null)
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: step.onTap, icon: Icon(step.icon, size: 18), label: Text(step.actionLabel.toUpperCase()))),
          Center(child: TextButton.icon(onPressed: onShowFullPlan, icon: const Icon(Icons.expand_more_rounded), label: const Text('Ver plan completo'))),
        ],
      ),
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
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
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
              if (step.completed) Icon(Icons.done_all_rounded, color: Colors.greenAccent) else Text(step.actionLabel, style: TextStyle(color: context.gymPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

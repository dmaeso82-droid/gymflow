part of '../user_dashboard.dart';

class _CompactHero extends StatelessWidget {
  final int streak;
  final String latestLogDate;
  final int weekSeries;
  final int trendPercent;
  final VoidCallback onTrain;

  const _CompactHero({
    required this.streak,
    required this.latestLogDate,
    required this.weekSeries,
    required this.trendPercent,
    required this.onTrain,
  });

  @override
  Widget build(BuildContext context) {
    final trendText = trendPercent >= 0 ? '+$trendPercent%' : '$trendPercent%';
    final weekProgress = (weekSeries / 20).clamp(0.0, 1.0).toDouble();
    final streakTitle = streak > 0 ? '$streak ${streak == 1 ? 'día' : 'días'}' : 'Empieza hoy';
    final streakSubtitle = streak > 0 ? 'ATLETA EN RACHA' : 'PRIMER ENTRENAMIENTO';

    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 28,
      gradient: context.gymHeroGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: context.gymFitnessAccent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(color: context.gymFitnessAccent.withValues(alpha: 0.22)),
                ),
                child: Icon(Icons.local_fire_department_rounded, color: context.gymFitnessAccent, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(streakSubtitle, style: TextStyle(color: context.gymPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                    const SizedBox(height: 3),
                    Text(streakTitle, style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, height: 1.0, color: context.gymText)),
                    const SizedBox(height: 5),
                    Text('Último entreno: $latestLogDate', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: Text('Progreso semanal', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
              Text('${(weekProgress * 100).round()}%', style: TextStyle(color: context.gymPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: weekProgress,
              minHeight: 9,
              backgroundColor: context.gymSubtleSurface.withValues(alpha: 0.72),
              valueColor: AlwaysStoppedAnimation<Color>(context.gymFitnessAccent),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(child: _MiniHeroStat(label: 'Series semana', value: '$weekSeries', icon: Icons.format_list_numbered_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _MiniHeroStat(label: 'Vs semana ant.', value: trendText, icon: trendPercent >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTrain,
              icon: const Icon(Icons.fitness_center_rounded),
              label: const Text('ENTRENAR AHORA'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniHeroStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniHeroStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.gymBorder.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.gymFitnessAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: context.gymFitnessAccent, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: context.gymText, height: 1.0)),
                const SizedBox(height: 2),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekSummaryCard extends StatelessWidget {
  final int weekSeries;
  final int previousSeries;
  final int weekExercises;
  final int previousExercises;
  final String bestWeight;
  final int pendingGoals;
  final int completedGoals;

  const _WeekSummaryCard({
    required this.weekSeries,
    required this.previousSeries,
    required this.weekExercises,
    required this.previousExercises,
    required this.bestWeight,
    required this.pendingGoals,
    required this.completedGoals,
  });

  String deltaText(int current, int previous) {
    final delta = current - previous;
    if (delta > 0) return '+$delta';
    return delta.toString();
  }

  @override
  Widget build(BuildContext context) {
    final goalTotal = pendingGoals + completedGoals;
    final goalProgress = goalTotal <= 0 ? 0.0 : (completedGoals / goalTotal).clamp(0.0, 1.0).toDouble();
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardHeader(icon: Icons.insights_rounded, title: 'Tu semana'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.gymPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.gymPrimary.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Objetivos completados', style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900))),
                    Text('$completedGoals/$goalTotal', style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: goalProgress,
                    minHeight: 8,
                    backgroundColor: context.gymProgressTrack,
                    valueColor: AlwaysStoppedAnimation<Color>(context.gymPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final width = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(width: width, child: _KpiCard(icon: Icons.format_list_numbered_rounded, value: '$weekSeries', label: 'Series', subtitle: '${deltaText(weekSeries, previousSeries)} vs anterior')),
                  SizedBox(width: width, child: _KpiCard(icon: Icons.directions_run_rounded, value: '$weekExercises', label: 'Ejercicios', subtitle: '${deltaText(weekExercises, previousExercises)} vs anterior')),
                  SizedBox(width: width, child: _KpiCard(icon: Icons.workspace_premium_rounded, value: bestWeight, label: 'Mejor marca', subtitle: 'Registro destacado')),
                  SizedBox(width: width, child: _KpiCard(icon: Icons.flag_rounded, value: '$pendingGoals', label: 'Pendientes', subtitle: '$completedGoals completados')),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String subtitle;

  const _KpiCard({required this.icon, required this.value, required this.label, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.gymBorder.withValues(alpha: 0.78)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.gymFitnessAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: context.gymFitnessAccent, size: 19),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: context.gymText, height: 1.0)),
                const SizedBox(height: 2),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11.5, fontWeight: FontWeight.w800)),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText.withValues(alpha: 0.70), fontSize: 10.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HighlightPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.gymBorder.withValues(alpha: 0.78)),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.gymFitnessAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

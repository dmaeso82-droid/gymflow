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
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
                child: Icon(Icons.local_fire_department, color: context.gymFitnessAccent, size: 30),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$streak ${streak == 1 ? 'día' : 'días'} de racha', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.0, color: context.gymText)),
                    SizedBox(height: 5),
                    Text('Último entreno: $latestLogDate', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniHeroStat(
                  label: 'Series semana',
                  value: '$weekSeries',
                  icon: Icons.format_list_numbered,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _MiniHeroStat(
                  label: 'Vs semana ant.',
                  value: trendText,
                  icon: trendPercent >= 0 ? Icons.trending_up : Icons.trending_down,
                ),
              ),
            ],
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.gymBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.gymFitnessAccent, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.gymText)),
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
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardHeader(icon: Icons.insights, title: 'Tu semana'),
          SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final width = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(width: width, child: _KpiCard(icon: Icons.format_list_numbered, value: '$weekSeries', label: 'Series', subtitle: '${deltaText(weekSeries, previousSeries)} vs anterior')),
                  SizedBox(width: width, child: _KpiCard(icon: Icons.directions_run, value: '$weekExercises', label: 'Ejercicios', subtitle: '${deltaText(weekExercises, previousExercises)} vs anterior')),
                  SizedBox(width: width, child: _KpiCard(icon: Icons.workspace_premium, value: bestWeight, label: 'Mejor marca', subtitle: 'Registro destacado')),
                  SizedBox(width: width, child: _KpiCard(icon: Icons.flag, value: '$pendingGoals', label: 'Objetivos', subtitle: '$completedGoals completados')),
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
      decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.gymBorder)),
      child: Row(
        children: [
          Icon(icon, color: context.gymFitnessAccent, size: 21),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: context.gymText)),
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
      decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.gymBorder)),
      child: Row(
        children: [
          Icon(icon, color: context.gymFitnessAccent, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

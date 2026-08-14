import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/duel_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/profile_avatar.dart';

class DuelCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final DuelService service;

  const DuelCard({super.key, required this.doc, required this.service});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final metric = data['metric']?.toString() ?? 'workout_count';
    final target = service.doubleValue(data['target']);
    final challengerName = data['challengerName']?.toString() ?? 'Retador';
    final opponentName = data['opponentName']?.toString() ?? 'Oponente';
    final status = data['status']?.toString() ?? 'active';

    return FutureBuilder<DuelProgress>(
      future: service.progressForDuel(doc),
      builder: (context, snapshot) {
        final progress = snapshot.data ?? const DuelProgress(challenger: 0, opponent: 0);
        final challengerPercent = target <= 0 ? 0.0 : (progress.challenger / target).clamp(0.0, 1.0).toDouble();
        final opponentPercent = target <= 0 ? 0.0 : (progress.opponent / target).clamp(0.0, 1.0).toDouble();
        final completed = status == 'completed' || progress.winnerId != null;

        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.22)),
                    ),
                    child: const Icon(Icons.sports_mma_rounded, color: Colors.amberAccent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$challengerName vs $opponentName', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('${service.metricLabel(metric)} · objetivo ${service.formatCompact(target)} ${service.metricUnit(metric)}', style: TextStyle(color: context.gymMutedText, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  _DuelStatusPill(completed: completed),
                ],
              ),
              const SizedBox(height: 14),
              DuelProgressRow(name: challengerName, value: progress.challenger, target: target, percent: challengerPercent, unit: service.metricUnit(metric)),
              const SizedBox(height: 10),
              DuelProgressRow(name: opponentName, value: progress.opponent, target: target, percent: opponentPercent, unit: service.metricUnit(metric)),
              if (completed) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.24)),
                  ),
                  child: Text('Ganador: ${progress.winnerName ?? data['winnerName'] ?? 'Pendiente'}', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w900)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DuelStatusPill extends StatelessWidget {
  final bool completed;

  const _DuelStatusPill({required this.completed});

  @override
  Widget build(BuildContext context) {
    final color = completed ? Colors.amberAccent : context.gymFitnessAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(completed ? Icons.emoji_events_rounded : Icons.timer_rounded, color: color, size: 14),
          const SizedBox(width: 4),
          Text(completed ? 'Finalizado' : 'Activo', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class DuelProgressRow extends StatelessWidget {
  final String name;
  final double value;
  final double target;
  final double percent;
  final String unit;

  const DuelProgressRow({super.key, required this.name, required this.value, required this.target, required this.percent, required this.unit});

  String formatCompact(num value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.gymBorder.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          ProfileAvatar(name: name, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.gymPrimary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${formatCompact(value)} / ${formatCompact(target)} $unit', style: TextStyle(color: context.gymPrimary, fontSize: 11.5, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                LinearProgressIndicator(
                  value: percent,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: context.gymProgressTrack,
                  color: context.gymFitnessAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sports_mma, color: Colors.amberAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$challengerName vs $opponentName',
                      style: TextStyle(color: context.gymText, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (completed)
                    const Icon(Icons.emoji_events, color: Colors.amberAccent)
                  else
                    Icon(Icons.timer, color: context.gymFitnessAccent),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${service.metricLabel(metric)} · objetivo ${service.formatCompact(target)} ${service.metricUnit(metric)}',
                style: TextStyle(color: context.gymMutedText),
              ),
              const SizedBox(height: 14),
              DuelProgressRow(
                name: challengerName,
                value: progress.challenger,
                target: target,
                percent: challengerPercent,
                unit: service.metricUnit(metric),
              ),
              const SizedBox(height: 10),
              DuelProgressRow(
                name: opponentName,
                value: progress.opponent,
                target: target,
                percent: opponentPercent,
                unit: service.metricUnit(metric),
              ),
              if (completed) ...[
                const SizedBox(height: 12),
                Text(
                  'Ganador: ${progress.winnerName ?? data['winnerName'] ?? 'Pendiente'}',
                  style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w900),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class DuelProgressRow extends StatelessWidget {
  final String name;
  final double value;
  final double target;
  final double percent;
  final String unit;

  const DuelProgressRow({
    super.key,
    required this.name,
    required this.value,
    required this.target,
    required this.percent,
    required this.unit,
  });

  String formatCompact(num value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileAvatar(name: name, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(name, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w800))),
                  Text('${formatCompact(value)} / ${formatCompact(target)} $unit', style: TextStyle(color: context.gymMutedText, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 5),
              LinearProgressIndicator(
                value: percent,
                minHeight: 7,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: context.gymProgressTrack,
                color: context.gymFitnessAccent,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

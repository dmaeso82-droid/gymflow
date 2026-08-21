import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/duel_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/profile_avatar.dart';

class DuelCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final DuelService service;
  final String currentUserId;
  final String currentUserEmail;
  final bool trainerMode;

  const DuelCard({
    super.key,
    required this.doc,
    required this.service,
    required this.currentUserId,
    required this.currentUserEmail,
    this.trainerMode = false,
  });

  bool isOpponent(Map<String, dynamic> data) {
    final opponentId = data['opponentId']?.toString() ?? '';
    final opponentEmail = (data['opponentEmail'] ?? '').toString().toLowerCase();
    return (currentUserId.isNotEmpty && opponentId == currentUserId) ||
        (currentUserEmail.isNotEmpty && opponentEmail == currentUserEmail.toLowerCase());
  }

  bool isChallenger(Map<String, dynamic> data) {
    final challengerId = data['challengerId']?.toString() ?? '';
    final challengerEmail = (data['challengerEmail'] ?? '').toString().toLowerCase();
    return (currentUserId.isNotEmpty && challengerId == currentUserId) ||
        (currentUserEmail.isNotEmpty && challengerEmail == currentUserEmail.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final metric = data['metric']?.toString() ?? 'workout_count';
    final target = service.doubleValue(data['target']);
    final challengerName = data['challengerName']?.toString() ?? 'Retador';
    final opponentName = data['opponentName']?.toString() ?? 'Oponente';
    final status = data['status']?.toString() ?? 'pending';

    if (status == 'pending') {
      return _PendingDuelCard(
        data: data,
        service: service,
        docId: doc.id,
        metric: metric,
        target: target,
        challengerName: challengerName,
        opponentName: opponentName,
        canRespond: isOpponent(data),
        isChallenger: isChallenger(data),
        currentUserId: currentUserId,
        currentUserEmail: currentUserEmail,
      );
    }

    if (status == 'declined') {
      return _DeclinedDuelCard(data: data, service: service, metric: metric, target: target, challengerName: challengerName, opponentName: opponentName);
    }

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
                  _DuelStatusPill(status: completed ? 'completed' : 'active'),
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

class _PendingDuelCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final DuelService service;
  final String docId;
  final String metric;
  final double target;
  final String challengerName;
  final String opponentName;
  final bool canRespond;
  final bool isChallenger;
  final String currentUserId;
  final String currentUserEmail;

  const _PendingDuelCard({
    required this.data,
    required this.service,
    required this.docId,
    required this.metric,
    required this.target,
    required this.challengerName,
    required this.opponentName,
    required this.canRespond,
    required this.isChallenger,
    required this.currentUserId,
    required this.currentUserEmail,
  });

  @override
  State<_PendingDuelCard> createState() => _PendingDuelCardState();
}

class _PendingDuelCardState extends State<_PendingDuelCard> {
  bool saving = false;

  Future<void> accept() async {
    setState(() => saving = true);
    await widget.service.acceptDuel(
      duelId: widget.docId,
      acceptedById: widget.currentUserId,
      acceptedByName: widget.opponentName,
      acceptedByEmail: widget.currentUserEmail,
    );
    if (mounted) {
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duelo aceptado.')));
    }
  }

  Future<void> decline() async {
    setState(() => saving = true);
    await widget.service.declineDuel(
      duelId: widget.docId,
      declinedById: widget.currentUserId,
      declinedByName: widget.opponentName,
      declinedByEmail: widget.currentUserEmail,
    );
    if (mounted) {
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duelo rechazado.')));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.orangeAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.22)),
                ),
                child: const Icon(Icons.hourglass_top_rounded, color: Colors.orangeAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.challengerName} vs ${widget.opponentName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text('${widget.service.metricLabel(widget.metric)} · objetivo ${widget.service.formatCompact(widget.target)} ${widget.service.metricUnit(widget.metric)}', style: TextStyle(color: context.gymMutedText, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const _DuelStatusPill(status: 'pending'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.18)),
            ),
            child: Text(
              widget.canRespond
                  ? '${widget.challengerName} te ha retado. El progreso empezará a contar cuando aceptes.'
                  : 'Esperando a que ${widget.opponentName} acepte el duelo. El progreso todavía no cuenta.',
              style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w800),
            ),
          ),
          if (widget.canRespond) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : decline,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: saving ? null : accept,
                    icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
                    label: const Text('Aceptar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DeclinedDuelCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final DuelService service;
  final String metric;
  final double target;
  final String challengerName;
  final String opponentName;

  const _DeclinedDuelCard({required this.data, required this.service, required this.metric, required this.target, required this.challengerName, required this.opponentName});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      radius: 24,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.block_rounded, color: Colors.redAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$challengerName vs $opponentName', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('Duelo rechazado · ${service.metricLabel(metric)}', style: TextStyle(color: context.gymMutedText, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const _DuelStatusPill(status: 'declined'),
        ],
      ),
    );
  }
}

class _DuelStatusPill extends StatelessWidget {
  final String status;

  const _DuelStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final completed = status == 'completed';
    final pending = status == 'pending';
    final declined = status == 'declined';
    final color = completed ? Colors.amberAccent : pending ? Colors.orangeAccent : declined ? Colors.redAccent : context.gymFitnessAccent;
    final label = completed ? 'Finalizado' : pending ? 'Pendiente' : declined ? 'Rechazado' : 'Activo';
    final icon = completed ? Icons.emoji_events_rounded : pending ? Icons.hourglass_top_rounded : declined ? Icons.block_rounded : Icons.timer_rounded;
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
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
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

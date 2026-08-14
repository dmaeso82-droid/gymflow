import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/challenge_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/profile_avatar.dart';

class TrainerChallengeCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final ChallengeService service;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDelete;

  const TrainerChallengeCard({
    super.key,
    required this.doc,
    required this.service,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final title = data['title']?.toString() ?? 'Reto';
    final description = data['description']?.toString() ?? '';
    final type = data['type']?.toString() ?? 'workout_count';
    final target = service.targetValue(data['target']);
    final active = data['active'] != false;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChallengeIconBox(icon: service.challengeIcon(type), active: active),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontSize: 18, fontWeight: FontWeight.w900)),
                        ),
                        _ChallengeStatusPill(active: active),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                  if (value == 'toggle') onToggleActive(!active);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'toggle', child: Text(active ? 'Desactivar' : 'Activar')),
                  const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChallengeChip(icon: service.challengeIcon(type), text: service.challengeTypeLabel(type)),
              ChallengeChip(icon: Icons.flag_rounded, text: '${service.formatCompact(target)} ${service.challengeUnit(type)}'),
              ChallengeChip(icon: active ? Icons.flash_on_rounded : Icons.pause_rounded, text: active ? 'Activo' : 'Inactivo'),
              ChallengeChip(icon: Icons.schedule_rounded, text: 'Creado ${service.formatDate(data['createdAt'])}'),
            ],
          ),
        ],
      ),
    );
  }
}

class UserChallengeCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> challengeDoc;
  final String userName;
  final ChallengeStats stats;
  final ChallengeService service;

  const UserChallengeCard({
    super.key,
    required this.challengeDoc,
    required this.userName,
    required this.stats,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final data = challengeDoc.data();
    final title = data['title']?.toString() ?? 'Reto';
    final description = data['description']?.toString() ?? '';
    final type = data['type']?.toString() ?? 'workout_count';
    final target = service.targetValue(data['target']);
    final current = service.progressForType(stats, type);
    final completed = target > 0 && current >= target;
    final percent = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0).toDouble();
    final progressColor = completed ? Colors.amberAccent : context.gymFitnessAccent;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ProfileAvatar(name: userName, size: 44),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: context.gymSurface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: context.gymBorder),
                      ),
                      child: Icon(completed ? Icons.check_rounded : service.challengeIcon(type), color: progressColor, size: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontSize: 18, fontWeight: FontWeight.w900))),
                        _ProgressPercentPill(percent: percent, completed: completed),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(service.challengeTypeLabel(type), style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w800, fontSize: 12.5)),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 10,
              backgroundColor: context.gymProgressTrack,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${service.formatCompact(current)} / ${service.formatCompact(target)} ${service.challengeUnit(type)}',
                  style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
              if (completed)
                _CompletedChallengePill()
              else
                ChallengeChip(icon: Icons.flag_rounded, text: 'Objetivo'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChallengeIconBox extends StatelessWidget {
  final IconData icon;
  final bool active;

  const _ChallengeIconBox({required this.icon, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.amberAccent : context.gymMutedText;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.gymIsDark ? 0.14 : 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Icon(icon, color: active ? Colors.amber.shade700 : context.gymMutedText),
    );
  }
}

class _ChallengeStatusPill extends StatelessWidget {
  final bool active;

  const _ChallengeStatusPill({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? context.gymPrimary : context.gymMutedText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(active ? 'Activo' : 'Inactivo', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class _ProgressPercentPill extends StatelessWidget {
  final double percent;
  final bool completed;

  const _ProgressPercentPill({required this.percent, required this.completed});

  @override
  Widget build(BuildContext context) {
    final color = completed ? Colors.amberAccent : context.gymPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text('${(percent * 100).round()}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }
}

class _CompletedChallengePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amberAccent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.24)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, color: Colors.amberAccent, size: 15),
          SizedBox(width: 5),
          Text('Completado', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 12)),
        ],
      ),
    );
  }
}

class ChallengeChip extends StatelessWidget {
  final String text;
  final IconData? icon;

  const ChallengeChip({super.key, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.gymBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: context.gymPrimary),
            const SizedBox(width: 5),
          ],
          Text(text, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

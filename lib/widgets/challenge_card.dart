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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: context.gymIsDark ? 0.14 : 0.18),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.22)),
                ),
                child: Icon(service.challengeIcon(type), color: Colors.amber.shade700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: context.gymText, fontSize: 18, fontWeight: FontWeight.w900)),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(description, style: TextStyle(color: context.gymMutedText)),
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
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(active ? 'Desactivar' : 'Activar'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Eliminar'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChallengeChip(text: service.challengeTypeLabel(type)),
              ChallengeChip(text: '${service.formatCompact(target)} ${service.challengeUnit(type)}'),
              ChallengeChip(text: active ? 'Activo' : 'Inactivo'),
              ChallengeChip(text: 'Creado ${service.formatDate(data['createdAt'])}'),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileAvatar(name: userName, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: context.gymText, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(
                      service.challengeTypeLabel(type),
                      style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w700),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(description, style: TextStyle(color: context.gymMutedText)),
                    ],
                  ],
                ),
              ),
              Icon(
                completed ? Icons.emoji_events : service.challengeIcon(type),
                color: progressColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                  style: TextStyle(color: context.gymText, fontWeight: FontWeight.w800),
                ),
              ),
              Text('${(percent * 100).round()}%', style: TextStyle(color: context.gymMutedText)),
            ],
          ),
          if (completed) ...[
            const SizedBox(height: 8),
            const Text('Reto completado', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }
}

class ChallengeChip extends StatelessWidget {
  final String text;

  const ChallengeChip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.gymBorder),
      ),
      child: Text(
        text,
        style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

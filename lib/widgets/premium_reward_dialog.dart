import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PremiumRewardPayload {
  final IconData icon;
  final String kicker;
  final String title;
  final String subtitle;
  final String pointsText;
  final Color color;

  const PremiumRewardPayload({
    required this.icon,
    required this.kicker,
    required this.title,
    required this.subtitle,
    required this.pointsText,
    required this.color,
  });

  factory PremiumRewardPayload.fromNotification(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final title = data['title']?.toString() ?? 'Recompensa desbloqueada';
    final message = data['message']?.toString() ?? '';
    final metadata = data['metadata'];
    final meta = metadata is Map ? Map<String, dynamic>.from(metadata) : <String, dynamic>{};

    if (type == 'achievement_unlocked') {
      final achievementTitle = meta['title']?.toString() ?? title;
      return PremiumRewardPayload(
        icon: Icons.emoji_events_rounded,
        kicker: 'LOGRO DESBLOQUEADO',
        title: achievementTitle,
        subtitle: message.isNotEmpty ? message : 'Has conseguido un nuevo logro en GymFlow.',
        pointsText: '+25 pts',
        color: Colors.amberAccent,
      );
    }

    if (type == 'challenge_completed') {
      return PremiumRewardPayload(
        icon: Icons.flag_rounded,
        kicker: 'RETO COMPLETADO',
        title: title,
        subtitle: message.isNotEmpty ? message : 'Has completado un reto de DalaiGym.',
        pointsText: '+75 pts',
        color: Colors.greenAccent,
      );
    }

    if (type == 'duel_won') {
      return PremiumRewardPayload(
        icon: Icons.sports_mma_rounded,
        kicker: 'DUELO GANADO',
        title: title,
        subtitle: message.isNotEmpty ? message : 'Has ganado un duelo 1 vs 1.',
        pointsText: '+50 pts',
        color: Colors.orangeAccent,
      );
    }

    if (type.startsWith('ranking_') && type.contains('top1')) {
      return PremiumRewardPayload(
        icon: Icons.workspace_premium_rounded,
        kicker: 'NUEVO Nº1',
        title: title,
        subtitle: message.isNotEmpty ? message : 'Has alcanzado el primer puesto del ranking.',
        pointsText: 'Ranking',
        color: Colors.amberAccent,
      );
    }

    if (type.startsWith('ranking_') && type.contains('top3')) {
      return PremiumRewardPayload(
        icon: Icons.leaderboard_rounded,
        kicker: 'TOP 3',
        title: title,
        subtitle: message.isNotEmpty ? message : 'Has entrado en el Top 3 del ranking.',
        pointsText: 'Top 3',
        color: Colors.amberAccent,
      );
    }

    return PremiumRewardPayload(
      icon: Icons.auto_awesome_rounded,
      kicker: 'RECOMPENSA',
      title: title,
      subtitle: message,
      pointsText: 'Nuevo',
      color: Colors.greenAccent,
    );
  }
}

Future<void> showPremiumRewardDialog({
  required BuildContext context,
  required PremiumRewardPayload reward,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar recompensa',
    barrierColor: Colors.black.withValues(alpha: 0.70),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: _PremiumRewardCard(reward: reward),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: curved, child: child),
      );
    },
  );
}

class _PremiumRewardCard extends StatelessWidget {
  final PremiumRewardPayload reward;

  const _PremiumRewardCard({required this.reward});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width.clamp(0, 420).toDouble();
    return Container(
      width: maxWidth - 32,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: context.gymHeroGradient,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: reward.color.withValues(alpha: 0.44), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: reward.color.withValues(alpha: 0.20),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: reward.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: reward.color.withValues(alpha: 0.30)),
            ),
            child: Icon(reward.icon, color: reward.color, size: 42),
          ),
          const SizedBox(height: 14),
          Text(
            reward.kicker,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: reward.color,
              fontSize: 12,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reward.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.gymText,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          if (reward.subtitle.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              reward.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.gymMutedText, fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: reward.color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: reward.color.withValues(alpha: 0.26)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, color: reward.color, size: 18),
                const SizedBox(width: 6),
                Text(reward.pointsText, style: TextStyle(color: reward.color, fontSize: 14, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_rounded),
              label: const Text('GENIAL'),
            ),
          ),
        ],
      ),
    );
  }
}

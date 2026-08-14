part of '../user_home_page.dart';

class _NextStepCard extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userEmail;
  final VoidCallback onOpenRoutines;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenRanking;
  const _NextStepCard({
    required this.gymId,
    required this.userId,
    required this.userEmail,
    required this.onOpenRoutines,
    required this.onOpenGoals,
    required this.onOpenRanking,
  });

  DocumentReference<Map<String, dynamic>> get statsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('user_stats').doc(userId);
  DocumentReference<Map<String, dynamic>> get leaderboardRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('leaderboard').doc(userId);

  int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String lastWorkoutText(dynamic value) {
    if (value is! Timestamp) return 'Aún no hay entrenos registrados';
    final date = value.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final workoutDay = DateTime(date.year, date.month, date.day);
    final days = today.difference(workoutDay).inDays;
    if (days == 0) return 'Has entrenado hoy';
    if (days == 1) return 'Último entreno ayer';
    return 'Último entreno hace $days días';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: statsRef.snapshots(),
      builder: (context, statsSnapshot) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: leaderboardRef.snapshots(),
          builder: (context, leaderboardSnapshot) {
            final stats = statsSnapshot.data?.data() ?? {};
            final leaderboard = leaderboardSnapshot.data?.data() ?? {};
            final workouts = intValue(stats['workouts']);
            final currentStreak = intValue(stats['currentStreak']);
            final points = intValue(stats['points']);
            final monthlyPoints = intValue(leaderboard['monthlyPoints']);
            final lastWorkout = stats['lastWorkout'];
            final hasTrained = lastWorkout is Timestamp;
            final title = hasTrained ? 'Sigue tu ritmo' : 'Empieza tu primer entreno';
            final subtitle = hasTrained
                ? '${lastWorkoutText(lastWorkout)} · $currentStreak días de racha · $points pts'
                : 'Abre tus rutinas y registra tu primer entrenamiento.';
            final buttonText = hasTrained ? 'Ir al entreno' : 'Ver rutinas';
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
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(19)),
                        child: Icon(hasTrained ? Icons.local_fire_department_rounded : Icons.play_arrow_rounded, color: context.gymPrimary, size: 28),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Tu próximo paso', style: TextStyle(color: context.gymPrimary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.7)),
                          SizedBox(height: 4),
                          Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.0)),
                          SizedBox(height: 5),
                          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 13, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _MiniProgressPill(icon: Icons.fitness_center_rounded, label: 'Entrenos', value: workouts.toString())),
                      SizedBox(width: 8),
                      Expanded(child: _MiniProgressPill(icon: Icons.emoji_events_rounded, label: 'Mes', value: '$monthlyPoints pts')),
                    ],
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: FilledButton.icon(onPressed: onOpenRoutines, icon: Icon(Icons.play_circle_fill_rounded), label: Text(buttonText))),
                      SizedBox(width: 8),
                      IconButton.filledTonal(onPressed: onOpenRanking, icon: Icon(Icons.leaderboard_rounded), tooltip: 'Ver ranking'),
                      SizedBox(width: 8),
                      IconButton.filledTonal(onPressed: onOpenGoals, icon: Icon(Icons.flag_rounded), tooltip: 'Ver objetivos'),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MiniProgressPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MiniProgressPill({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: 0.86), borderRadius: BorderRadius.circular(17), border: Border.all(color: context.gymBorder)),
      child: Row(children: [
        Icon(icon, color: context.gymPrimary, size: 18),
        SizedBox(width: 7),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/achievement_service.dart';
import '../services/workout_service.dart';
import '../theme/app_theme.dart';
import '../utils/workout_utils.dart';
import '../widgets/app_card.dart';
import '../widgets/routine_card.dart';
import '../widgets/workout_log_dialog.dart';
import 'routine_comments_page.dart';

class UserRoutinesPage extends StatefulWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;

  const UserRoutinesPage({
    super.key,
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<UserRoutinesPage> createState() => _UserRoutinesPageState();
}

class _UserRoutinesPageState extends State<UserRoutinesPage> {
  final ScrollController _scrollController = ScrollController();

  WorkoutService get service => WorkoutService(
        gymId: widget.gymId,
        userId: widget.userId,
        userName: widget.userName,
        userEmail: widget.userEmail,
      );

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double get _currentScrollOffset {
    if (!_scrollController.hasClients) return 0;
    return _scrollController.offset;
  }

  void _restoreScrollOffset(double offset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      final target = offset.clamp(0.0, max).toDouble();
      _scrollController.jumpTo(target);
    });
  }

  Future<void> _restoreScrollOffsetAfterRefresh(double offset) async {
    _restoreScrollOffset(offset);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    _restoreScrollOffset(offset);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    _restoreScrollOffset(offset);
  }

  Future<void> showUnlockedAchievementDialog({
    required BuildContext context,
    required WorkoutService workoutService,
    required UnlockedAchievementData achievement,
  }) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.gymSurface,
          title: Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amberAccent),
              SizedBox(width: 8),
              Expanded(child: Text('Logro desbloqueado')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                achievement.title,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.amberAccent),
              ),
              SizedBox(height: 8),
              Text(achievement.description, style: TextStyle(color: context.gymMutedText)),
              SizedBox(height: 12),
              Text('¿Quieres compartirlo en Comunidad?', style: TextStyle(color: context.gymMutedText)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'close'),
              child: Text('Cerrar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, 'share'),
              icon: Icon(Icons.share),
              label: Text('Compartir'),
            ),
          ],
        );
      },
    );

    if (action == 'share') {
      await workoutService.shareAchievementToCommunity(achievement);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logro compartido en Comunidad.')));
      }
    }
  }

  Future<void> showUnlockedAchievements({
    required BuildContext context,
    required WorkoutService workoutService,
    required List<UnlockedAchievementData> achievements,
  }) async {
    for (final achievement in achievements) {
      if (!context.mounted) return;
      await showUnlockedAchievementDialog(
        context: context,
        workoutService: workoutService,
        achievement: achievement,
      );
    }
  }

  Future<void> logWorkoutSet({
    required BuildContext context,
    required String routineId,
    required String routineTitle,
    required List<dynamic> exercises,
    required String exerciseId,
  }) async {
    final savedScrollOffset = _currentScrollOffset;
    final workoutService = service;
    final result = await showWorkoutLogDialog(
      context: context,
      exercises: exercises,
      exerciseId: exerciseId,
    );
    if (result == null || !context.mounted) {
      await _restoreScrollOffsetAfterRefresh(savedScrollOffset);
      return;
    }

    final newAchievements = await workoutService.saveWorkoutLog(
      routineId: routineId,
      routineTitle: routineTitle,
      exercise: result.exercise,
      weight: result.weight,
      reps: result.reps,
      setNumber: result.setNumber,
      plannedSetCount: result.plannedSetCount,
    );
    if (!context.mounted) return;

    final progress = await workoutService.updateExerciseSetProgress(
      routineId,
      exercises,
      exerciseId,
    );
    if (!context.mounted) return;

    await _restoreScrollOffsetAfterRefresh(savedScrollOffset);

    var allNewAchievements = List<UnlockedAchievementData>.from(newAchievements);
    if (progress.routineCompleted) {
      final challengeAchievements = await workoutService.updateWorkoutChallenges(routineTitle: routineTitle);
      allNewAchievements = [...allNewAchievements, ...challengeAchievements];
    }
    if (!context.mounted) return;

    final completedMessage = result.setNumber >= result.plannedSetCount
        ? 'Ejercicio completado. Has registrado ${result.plannedSetCount}/${result.plannedSetCount} series.'
        : 'Serie guardada. Llevas ${result.setNumber}/${result.plannedSetCount} series.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(completedMessage)));

    if (allNewAchievements.isNotEmpty && context.mounted) {
      final unique = <String, UnlockedAchievementData>{};
      for (final achievement in allNewAchievements) {
        unique[achievement.id] = achievement;
      }
      await showUnlockedAchievements(
        context: context,
        workoutService: workoutService,
        achievements: unique.values.toList(),
      );
    }
  }

  Future<void> updateExerciseDone(
    String routineId,
    List<dynamic> exercises,
    String exerciseId,
    bool done,
  ) async {
    final savedScrollOffset = _currentScrollOffset;
    await service.updateExerciseDone(routineId, exercises, exerciseId, done);
    await _restoreScrollOffsetAfterRefresh(savedScrollOffset);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> sortRoutines(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> routines,
  ) {
    final sorted = [...routines];
    sorted.sort((a, b) {
      final aOrder = a.data()['dayOrder'] is int
          ? a.data()['dayOrder'] as int
          : routineDayOrder((a.data()['day'] ?? '').toString());
      final bOrder = b.data()['dayOrder'] is int
          ? b.data()['dayOrder'] as int
          : routineDayOrder((b.data()['day'] ?? '').toString());
      final orderCompare = aOrder.compareTo(bOrder);
      if (orderCompare != 0) return orderCompare;
      return (a.data()['title'] ?? '').toString().compareTo((b.data()['title'] ?? '').toString());
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final workoutService = service;
    return Scaffold(
      appBar: AppBar(title: Text('Mis rutinas')),
      body: SafeArea(
        child: ListView(
          key: const PageStorageKey<String>('user_routines_scroll_position'),
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: workoutService.routinesRef.where('clientEmail', isEqualTo: widget.userEmail.toLowerCase()).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return AppCard(
                    child: Column(
                      children: [
                        Icon(Icons.wifi_off_rounded, color: Colors.orangeAccent, size: 42),
                        SizedBox(height: 12),
                        Text(
                          'No se han podido cargar tus rutinas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Vuelve a intentarlo. Si estabas cambiando entre apps, esto evita que la pantalla se quede en negro.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.gymMutedText),
                        ),
                        SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () {
                            if (mounted) setState(() {});
                          },
                          icon: Icon(Icons.refresh),
                          label: Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final routines = sortRoutines(
                  (snapshot.data?.docs ?? [])
                      .where((doc) => workoutService.isActiveRoutine(doc.data()))
                      .toList(),
                );

                if (routines.isEmpty) {
                  return AppCard(
                    child: Center(
                      child: Text(
                        'Todavía no tienes rutinas activas asignadas.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }


                return _RoutineList(
                  gymId: widget.gymId,
                  userId: widget.userId,
                  userName: widget.userName,
                  userEmail: widget.userEmail,
                  routines: routines,
                  onToggleExercise: updateExerciseDone,
                  onLogWorkout: logWorkoutSet,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineList extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> routines;
  final Future<void> Function(String routineId, List<dynamic> exercises, String exerciseId, bool done) onToggleExercise;
  final Future<void> Function({
    required BuildContext context,
    required String routineId,
    required String routineTitle,
    required List<dynamic> exercises,
    required String exerciseId,
  }) onLogWorkout;

  const _RoutineList({
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.routines,
    required this.onToggleExercise,
    required this.onLogWorkout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: routines.map((doc) {
        final data = doc.data();
        final exercises = List<dynamic>.from(data['exercises'] ?? []);
        final routineTitle = data['title'] ?? 'Sin título';
        return RoutineCard(
          key: ValueKey('routine-card-${doc.id}'),
          title: routineTitle,
          day: data['day'] ?? 'Sin día',
          notes: data['notes'] ?? '',
          clientName: 'Mi rutina',
          exercises: exercises,
          trainerMode: false,
          commentsCount: workoutIntValue(data['commentsCount']),
          onOpenComments: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoutineCommentsPage(
                gymId: gymId,
                routineId: doc.id,
                routineTitle: routineTitle,
                currentUserId: userId,
                currentUserName: userName,
                currentUserEmail: userEmail,
              ),
            ),
          ),
          onToggleExercise: (exerciseId, done) => onToggleExercise(doc.id, exercises, exerciseId, done),
          onLogWorkout: (exerciseId) => onLogWorkout(
            context: context,
            routineId: doc.id,
            routineTitle: routineTitle,
            exercises: exercises,
            exerciseId: exerciseId,
          ),
        );
      }).toList(),
    );
  }
}




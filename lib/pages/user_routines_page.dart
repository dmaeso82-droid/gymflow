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
  bool _initialDayScrollDone = false;

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

  int dayOrderForRoutine(QueryDocumentSnapshot<Map<String, dynamic>> routine) {
    final data = routine.data();
    if (data['dayOrder'] is int) return data['dayOrder'] as int;
    return routineDayOrder((data['day'] ?? '').toString());
  }

  String? targetRoutineIdForToday(List<QueryDocumentSnapshot<Map<String, dynamic>>> routines) {
    if (routines.isEmpty) return null;
    final todayOrder = DateTime.now().weekday;
    final sorted = sortRoutines(routines);
    for (final routine in sorted) {
      final order = dayOrderForRoutine(routine);
      if (order >= todayOrder) return routine.id;
    }
    return sorted.first.id;
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
          title: const Row(
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.amberAccent),
              ),
              const SizedBox(height: 8),
              Text(achievement.description, style: TextStyle(color: context.gymMutedText)),
              const SizedBox(height: 12),
              Text('¿Quieres compartirlo en Comunidad?', style: TextStyle(color: context.gymMutedText)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, 'close'), child: const Text('Cerrar')),
            FilledButton.icon(onPressed: () => Navigator.pop(dialogContext, 'share'), icon: const Icon(Icons.share), label: const Text('Compartir')),
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
      await showUnlockedAchievementDialog(context: context, workoutService: workoutService, achievement: achievement);
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
    final result = await showWorkoutLogDialog(context: context, exercises: exercises, exerciseId: exerciseId);
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
    final progress = await workoutService.updateExerciseSetProgress(routineId, exercises, exerciseId);
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
      await showUnlockedAchievements(context: context, workoutService: workoutService, achievements: unique.values.toList());
    }
  }

  Future<void> updateExerciseDone(String routineId, List<dynamic> exercises, String exerciseId, bool done) async {
    final savedScrollOffset = _currentScrollOffset;
    await service.updateExerciseDone(routineId, exercises, exerciseId, done);
    await _restoreScrollOffsetAfterRefresh(savedScrollOffset);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> sortRoutines(List<QueryDocumentSnapshot<Map<String, dynamic>>> routines) {
    final sorted = [...routines];
    sorted.sort((a, b) {
      final aOrder = a.data()['dayOrder'] is int ? a.data()['dayOrder'] as int : routineDayOrder((a.data()['day'] ?? '').toString());
      final bOrder = b.data()['dayOrder'] is int ? b.data()['dayOrder'] as int : routineDayOrder((b.data()['day'] ?? '').toString());
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
      appBar: AppBar(title: const Text('Mis rutinas')),
      body: SafeArea(
        child: ListView(
          key: const PageStorageKey<String>('user_routines_scroll_position'),
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 92),
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: workoutService.routinesRef.where('clientEmail', isEqualTo: widget.userEmail.toLowerCase()).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _RoutinesErrorState(onRetry: () {
                    if (mounted) setState(() {});
                  });
                }
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return Center(child: CircularProgressIndicator(color: context.gymPrimary));
                }
                final routines = sortRoutines((snapshot.data?.docs ?? []).where((doc) => workoutService.isActiveRoutine(doc.data())).toList());
                if (routines.isEmpty) return const _RoutinesEmptyState();
                final targetRoutineId = _initialDayScrollDone ? null : targetRoutineIdForToday(routines);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RoutinesHero(routines: routines),
                    const SizedBox(height: 12),
                    _RoutineQuickStats(routines: routines),
                    const SizedBox(height: 14),
                    _RoutineList(
                      gymId: widget.gymId,
                      userId: widget.userId,
                      userName: widget.userName,
                      userEmail: widget.userEmail,
                      routines: routines,
                      targetRoutineId: targetRoutineId,
                      onInitialScrollComplete: () {
                        if (mounted && !_initialDayScrollDone) {
                          setState(() => _initialDayScrollDone = true);
                        }
                      },
                      onToggleExercise: updateExerciseDone,
                      onLogWorkout: logWorkoutSet,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutinesHero extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> routines;

  const _RoutinesHero({required this.routines});

  int get totalExercises {
    var total = 0;
    for (final routine in routines) {
      total += List<dynamic>.from(routine.data()['exercises'] ?? []).length;
    }
    return total;
  }

  int get averageProgress {
    if (routines.isEmpty) return 0;
    var total = 0;
    for (final routine in routines) {
      total += routineSetSummary(List<dynamic>.from(routine.data()['exercises'] ?? [])).progressPercent;
    }
    return (total / routines.length).round();
  }

  String get mainRoutineTitle {
    final todayOrder = DateTime.now().weekday;
    QueryDocumentSnapshot<Map<String, dynamic>> selected = routines.first;
    for (final routine in routines) {
      final data = routine.data();
      final order = data['dayOrder'] is int ? data['dayOrder'] as int : routineDayOrder((data['day'] ?? '').toString());
      if (order >= todayOrder) {
        selected = routine;
        break;
      }
    }
    final data = selected.data();
    final raw = (data['title'] ?? 'Rutina activa').toString().trim();
    if (raw.contains('·')) {
      final last = raw.split('·').last.trim();
      if (last.isNotEmpty) return last;
    }
    return raw.isEmpty ? 'Rutina activa' : raw;
  }

  @override
  Widget build(BuildContext context) {
    final progress = averageProgress;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [context.gymPrimary, context.gymFitnessAccent]),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: context.gymPrimary.withValues(alpha: context.gymIsDark ? 0.26 : 0.18), blurRadius: 26, spreadRadius: -8, offset: const Offset(0, 16)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.fitness_center_rounded, color: Colors.white, size: 27),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Entrena hoy', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
            const SizedBox(height: 3),
            Text(mainRoutineTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13, fontWeight: FontWeight.w800)),
          ])),
          Text('$progress%', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(minHeight: 8, value: (progress / 100).clamp(0.0, 1.0), backgroundColor: Colors.white.withValues(alpha: 0.22), valueColor: const AlwaysStoppedAnimation<Color>(Colors.white)),
        ),
        const SizedBox(height: 9),
        Text('${routines.length} rutina${routines.length == 1 ? '' : 's'} activa${routines.length == 1 ? '' : 's'} · $totalExercises ejercicios', style: TextStyle(color: Colors.white.withValues(alpha: 0.86), fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _RoutineQuickStats extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> routines;

  const _RoutineQuickStats({required this.routines});

  int progressFor(QueryDocumentSnapshot<Map<String, dynamic>> routine) {
    return routineSetSummary(List<dynamic>.from(routine.data()['exercises'] ?? [])).progressPercent;
  }

  int get completedRoutines => routines.where((routine) => progressFor(routine) >= 100).length;

  int get totalExercises {
    var total = 0;
    for (final routine in routines) {
      total += List<dynamic>.from(routine.data()['exercises'] ?? []).length;
    }
    return total;
  }

  int get pendingRoutines => routines.length - completedRoutines;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(children: [
        _RoutineStatChip(icon: Icons.check_circle_rounded, value: '$completedRoutines', label: 'completadas', color: Colors.greenAccent),
        const SizedBox(width: 8),
        _RoutineStatChip(icon: Icons.fitness_center_rounded, value: '$totalExercises', label: 'ejercicios', color: context.gymPrimary),
        const SizedBox(width: 8),
        _RoutineStatChip(icon: Icons.local_fire_department_rounded, value: '$pendingRoutines', label: 'pendientes', color: context.gymFitnessAccent),
      ]),
    );
  }
}

class _RoutineStatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _RoutineStatChip({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.46 : 0.68), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 7),
        Text(value, style: TextStyle(color: context.gymText, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _RoutinesEmptyState extends StatelessWidget {
  const _RoutinesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(28)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 54, height: 54, decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(22)), child: Icon(Icons.fitness_center_rounded, color: context.gymPrimary, size: 30)),
        const SizedBox(height: 12),
        Text('Rutinas pendientes', textAlign: TextAlign.center, style: TextStyle(color: context.gymText, fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Tu entrenador todavía no te ha asignado una rutina activa.', textAlign: TextAlign.center, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _RoutinesErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _RoutinesErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(children: [
        const Icon(Icons.wifi_off_rounded, color: Colors.orangeAccent, size: 42),
        const SizedBox(height: 12),
        const Text('No se han podido cargar tus rutinas.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('Vuelve a intentarlo. Si estabas cambiando entre apps, esto evita que la pantalla se quede en negro.', textAlign: TextAlign.center, style: TextStyle(color: context.gymMutedText)),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
      ]),
    );
  }
}

class _RoutineList extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> routines;
  final String? targetRoutineId;
  final VoidCallback onInitialScrollComplete;
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
    required this.targetRoutineId,
    required this.onInitialScrollComplete,
    required this.onToggleExercise,
    required this.onLogWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final targetKey = targetRoutineId == null ? null : GlobalObjectKey('routine-auto-scroll-$targetRoutineId');
    if (targetKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = targetKey.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(targetContext, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic, alignment: 0.08);
        }
        onInitialScrollComplete();
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text('Rutinas activas', style: TextStyle(color: context.gymText, fontSize: 18, fontWeight: FontWeight.w900)),
        ),
        ...routines.map((doc) {
          final data = doc.data();
          final exercises = List<dynamic>.from(data['exercises'] ?? []);
          final routineTitle = data['title'] ?? 'Sin título';
          final routineCard = RoutineCard(
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
          if (doc.id == targetRoutineId && targetKey != null) {
            return KeyedSubtree(key: targetKey, child: routineCard);
          }
          return routineCard;
        }),
      ],
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_service.dart';
import 'stats_service.dart';
import 'points_service.dart';

class DuelUserOption {
  final String id;
  final String name;
  final String email;

  const DuelUserOption({required this.id, required this.name, required this.email});
}

class DuelProgress {
  final double challenger;
  final double opponent;
  final String? winnerId;
  final String? winnerName;

  const DuelProgress({
    required this.challenger,
    required this.opponent,
    this.winnerId,
    this.winnerName,
  });
}

class DuelService {
  final String gymId;

  const DuelService({required this.gymId});

  CollectionReference<Map<String, dynamic>> get duelsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('duels');

  CollectionReference<Map<String, dynamic>> get clientsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('clients');

  CollectionReference<Map<String, dynamic>> get logsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('workout_logs');


  StatsService get statsService => StatsService(gymId: gymId);
  PointsService get pointsService => PointsService(gymId: gymId);

  CollectionReference<Map<String, dynamic>> get communityRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('community_posts');

  int intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double doubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
  }

  String formatCompact(num value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  String metricLabel(String metric) {
    switch (metric) {
      case 'volume_total':
        return 'Volumen movido';
      case 'series_count':
        return 'Series completadas';
      case 'workout_count':
      default:
        return 'Entrenamientos completados';
    }
  }

  String metricUnit(String metric) {
    switch (metric) {
      case 'volume_total':
        return 'kg';
      case 'series_count':
        return 'series';
      case 'workout_count':
      default:
        return 'entrenos';
    }
  }

  Future<List<DuelUserOption>> loadClientOptions() async {
    final snapshot = await clientsRef.orderBy('name').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final authUid = data['authUid']?.toString() ?? '';
      return DuelUserOption(
        id: authUid.isNotEmpty ? authUid : doc.id,
        name: data['name']?.toString() ?? 'Usuario',
        email: (data['email'] ?? '').toString().toLowerCase(),
      );
    }).where((user) => user.email.isNotEmpty).toList();
  }

  DateTime? readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  bool isInsideDuelWindow(Map<String, dynamic> log, DateTime? start, DateTime? end) {
    final createdAt = readDate(log['createdAt']);
    if (createdAt == null) return false;
    if (start != null && createdAt.isBefore(start)) return false;
    if (end != null) {
      final exclusiveEnd = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
      if (!createdAt.isBefore(exclusiveEnd)) return false;
    }
    return true;
  }

  Future<double> metricProgress({
    required String userEmail,
    required String metric,
    DateTime? start,
    DateTime? end,
  }) async {
    Query<Map<String, dynamic>> query = logsRef.where('userEmail', isEqualTo: userEmail.toLowerCase());
    if (start != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
    }
    if (end != null) {
      final exclusiveEnd = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
      query = query.where('createdAt', isLessThan: Timestamp.fromDate(exclusiveEnd));
    }
    final snapshot = await query.get();
    final logs = snapshot.docs.map((doc) => doc.data()).where((log) => isInsideDuelWindow(log, start, end)).toList();

    if (metric == 'series_count') return logs.length.toDouble();

    if (metric == 'volume_total') {
      double total = 0;
      for (final log in logs) {
        total += doubleValue(log['weight']) * intValue(log['reps']);
      }
      return total;
    }

    final workoutKeys = <String>{};
    for (final log in logs) {
      final date = readDate(log['createdAt']);
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day).toIso8601String();
      final routineKey = log['routineId']?.toString() ?? log['routineTitle']?.toString() ?? 'routine';
      workoutKeys.add('$routineKey-$day');
    }
    return workoutKeys.length.toDouble();
  }

  Future<void> createDuel({
    required DuelUserOption challenger,
    required DuelUserOption opponent,
    required String metric,
    required double target,
    required int points,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    const allowedMetrics = {'volume_total', 'series_count', 'workout_count'};
    if (challenger.id == opponent.id || challenger.email.toLowerCase() == opponent.email.toLowerCase()) {
      throw ArgumentError('Los participantes del duelo deben ser distintos.');
    }
    if (!allowedMetrics.contains(metric) || target <= 0 || !target.isFinite || points <= 0) {
      throw ArgumentError('La métrica, el objetivo o los puntos del duelo no son válidos.');
    }
    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
      throw ArgumentError('La fecha final no puede ser anterior a la fecha inicial.');
    }
    final duelRef = await duelsRef.add({
      'type': 'duel',
      'metric': metric,
      'target': target,
      'points': points,
      'challengerId': challenger.id,
      'challengerName': challenger.name,
      'challengerEmail': challenger.email,
      'opponentId': opponent.id,
      'opponentName': opponent.name,
      'opponentEmail': opponent.email,
      'status': 'pending',
      'winnerId': '',
      'winnerName': '',
      'startDate': null,
      'proposedStartDate': startDate == null ? null : Timestamp.fromDate(startDate),
      'endDate': endDate == null ? null : Timestamp.fromDate(endDate),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await NotificationService(gymId: gymId).createNotification(
      userId: opponent.id,
      userEmail: opponent.email,
      type: 'duel_created',
      title: 'Nuevo duelo 1 vs 1',
      message: '${challenger.name} te ha retado en ${metricLabel(metric)}.',
      sourceId: duelRef.id,
      metadata: {
        'challengerId': challenger.id,
        'challengerName': challenger.name,
        'metric': metric,
      },
    );
  }

  Future<DuelProgress> progressForDuel(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final metric = data['metric']?.toString() ?? 'workout_count';
    final target = doubleValue(data['target']);
    final status = data['status']?.toString() ?? 'pending';
    if (status == 'pending' || status == 'declined') {
      return const DuelProgress(challenger: 0, opponent: 0);
    }
    final challengerEmail = (data['challengerEmail'] ?? '').toString();
    final opponentEmail = (data['opponentEmail'] ?? '').toString();
    final start = readDate(data['startDate']) ?? readDate(data['createdAt']);
    final end = readDate(data['endDate']);

    // Si Firestore aun no ha resuelto startDate/createdAt, no evaluamos.
    // Evita que un duelo recien creado cuente todo el historico y se complete solo.
    if (start == null && status != 'completed') {
      return const DuelProgress(challenger: 0, opponent: 0);
    }

    final challenger = await metricProgress(userEmail: challengerEmail, metric: metric, start: start, end: end);
    final opponent = await metricProgress(userEmail: opponentEmail, metric: metric, start: start, end: end);

    String? winnerId;
    String? winnerName;
    if (status == 'completed') {
      winnerId = data['winnerId']?.toString();
      winnerName = data['winnerName']?.toString();
    } else if (target > 0 && (challenger >= target || opponent >= target) && (challenger > 0 || opponent > 0)) {
      final challengerWon = challenger >= target && challenger >= opponent;
      winnerId = challengerWon ? data['challengerId']?.toString() : data['opponentId']?.toString();
      winnerName = challengerWon ? data['challengerName']?.toString() : data['opponentName']?.toString();
      await completeDuel(doc.id, data, winnerId ?? '', winnerName ?? 'Ganador');
    }

    return DuelProgress(
      challenger: challenger,
      opponent: opponent,
      winnerId: winnerId,
      winnerName: winnerName,
    );
  }

  Future<void> acceptDuel({
    required String duelId,
    required String acceptedById,
    required String acceptedByName,
    required String acceptedByEmail,
  }) async {
    final duelDoc = await duelsRef.doc(duelId).get();
    final data = duelDoc.data();
    if (data == null) return;
    if ((data['status'] ?? 'pending') != 'pending') return;

    await duelsRef.doc(duelId).set({
      'status': 'active',
      'acceptedBy': acceptedById,
      'acceptedByName': acceptedByName,
      'acceptedAt': FieldValue.serverTimestamp(),
      'startDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await NotificationService(gymId: gymId).createNotification(
      userId: data['challengerId']?.toString() ?? '',
      userEmail: data['challengerEmail']?.toString() ?? '',
      type: 'duel_accepted',
      title: 'Duelo aceptado',
      message: '$acceptedByName ha aceptado tu duelo. El progreso empieza a contar desde ahora.',
      sourceId: duelId,
    );
  }

  Future<void> declineDuel({
    required String duelId,
    required String declinedById,
    required String declinedByName,
    required String declinedByEmail,
  }) async {
    final duelDoc = await duelsRef.doc(duelId).get();
    final data = duelDoc.data();
    if (data == null) return;
    if ((data['status'] ?? 'pending') != 'pending') return;

    await duelsRef.doc(duelId).set({
      'status': 'declined',
      'declinedBy': declinedById,
      'declinedByName': declinedByName,
      'declinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await NotificationService(gymId: gymId).createNotification(
      userId: data['challengerId']?.toString() ?? '',
      userEmail: data['challengerEmail']?.toString() ?? '',
      type: 'duel_declined',
      title: 'Duelo rechazado',
      message: '$declinedByName ha rechazado tu duelo.',
      sourceId: duelId,
    );
  }

  Future<void> completeDuel(String duelId, Map<String, dynamic> data, String winnerId, String winnerName) async {
    if (winnerId.isEmpty) return;
    final currentDuel = await duelsRef.doc(duelId).get();
    if ((currentDuel.data()?['status'] ?? 'active') == 'completed') return;
    final points = intValue(data['points'], fallback: 100);
    final winnerEmail = winnerId == data['challengerId'] ? data['challengerEmail']?.toString() ?? '' : data['opponentEmail']?.toString() ?? '';

    final batch = FirebaseFirestore.instance.batch();
    final duelRef = duelsRef.doc(duelId);

    batch.update(duelRef, {
      'status': 'completed',
      'winnerId': winnerId,
      'winnerName': winnerName,
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });


    batch.set(communityRef.doc(), {
      'type': 'duel_completed',
      'userId': winnerId,
      'userName': winnerName,
      'userEmail': winnerEmail.toLowerCase(),
      'title': 'Duelo ganado',
      'message': '$winnerName ha ganado un duelo contra ${winnerId == data['challengerId'] ? data['opponentName'] : data['challengerName']} y suma $points puntos.',
      'duelId': duelId,
      'likes': [],
      'likeUsers': {},
      'commentsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    final loserId = winnerId == data['challengerId'] ? data['opponentId']?.toString() ?? '' : data['challengerId']?.toString() ?? '';
    final loserName = winnerId == data['challengerId'] ? data['opponentName']?.toString() ?? 'Oponente' : data['challengerName']?.toString() ?? 'Retador';
    final loserEmail = winnerId == data['challengerId'] ? data['opponentEmail']?.toString() ?? '' : data['challengerEmail']?.toString() ?? '';
    final notificationService = NotificationService(gymId: gymId);

    await notificationService.createNotification(
      userId: winnerId,
      userEmail: winnerEmail,
      type: 'duel_won',
      title: 'Has ganado un duelo',
      message: 'Has ganado contra $loserName y sumas $points puntos.',
      sourceId: duelId,
    );

    await notificationService.createNotification(
      userId: loserId,
      userEmail: loserEmail,
      type: 'duel_lost',
      title: 'Duelo finalizado',
      message: '$winnerName ha ganado el duelo.',
      sourceId: duelId,
    );
  }
}




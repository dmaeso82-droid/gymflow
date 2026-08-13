import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_formatters.dart';
import 'day_utils.dart';
int workoutIntValue(dynamic value, {int fallback = 0}) {
  return AppFormatters.intValue(value, fallback: fallback, extractFirstNumber: true);
}

double workoutDoubleValue(dynamic value) {
  return AppFormatters.doubleValue(value);
}

double? workoutDecimalValue(String value) => AppFormatters.decimalValue(value);

String workoutFormatWeight(double value) => AppFormatters.formatWeight(value);

int workoutTotalSets(Map<String, dynamic> exercise) {
  final parsed = AppFormatters.intValue(exercise['sets'], fallback: 1, extractFirstNumber: true);
  return parsed <= 0 ? 1 : parsed;
}

int workoutCompletedSets(Map<String, dynamic> exercise) {
  final total = workoutTotalSets(exercise);
  final rawCompleted = AppFormatters.intValue(exercise['completedSets'], fallback: -1, extractFirstNumber: true);
  if (rawCompleted >= 0) return rawCompleted.clamp(0, total).toInt();
  if (exercise['done'] == true) return total;
  return 0;
}

int routineDayOrder(String day) => DayUtils.order(day);

bool isClosedTrainingDay(DateTime day) => day.weekday == DateTime.sunday;

DateTime previousOpenTrainingDay(DateTime day) {
  var candidate = day.subtract(const Duration(days: 1));
  while (isClosedTrainingDay(candidate)) {
    candidate = candidate.subtract(const Duration(days: 1));
  }
  return candidate;
}

int calculateOpenDayStreak(Set<DateTime> days) {
  final openDays = days.where((day) => !isClosedTrainingDay(day)).toSet();
  if (openDays.isEmpty) return 0;

  var currentDay = DateTime.now();
  currentDay = DateTime(currentDay.year, currentDay.month, currentDay.day);

  while (isClosedTrainingDay(currentDay)) {
    currentDay = previousOpenTrainingDay(currentDay);
  }

  var streak = 0;
  if (!openDays.contains(currentDay)) {
    final previous = previousOpenTrainingDay(currentDay);
    if (openDays.contains(previous)) {
      currentDay = previous;
    } else {
      return 0;
    }
  }

  while (openDays.contains(currentDay)) {
    streak += 1;
    currentDay = previousOpenTrainingDay(currentDay);
  }
  return streak;
}

DateTime? dayFromTimestamp(dynamic value) {
  if (value is! Timestamp) return null;
  final date = value.toDate();
  return DateTime(date.year, date.month, date.day);
}

class RoutineSetSummary {
  final int totalSets;
  final int completedSets;
  final int totalExercises;
  final int completedExercises;

  const RoutineSetSummary({
    required this.totalSets,
    required this.completedSets,
    required this.totalExercises,
    required this.completedExercises,
  });

  int get progressPercent {
    if (totalSets == 0) return 0;
    return ((completedSets / totalSets) * 100).round().clamp(0, 100).toInt();
  }

  bool get completed => totalSets > 0 && completedSets >= totalSets;
}

RoutineSetSummary routineSetSummary(List<dynamic> exercises) {
  var totalSets = 0;
  var completedSets = 0;
  var totalExercises = 0;
  var completedExercises = 0;

  for (final item in exercises) {
    final exercise = Map<String, dynamic>.from(item as Map);
    final total = workoutTotalSets(exercise);
    final completed = workoutCompletedSets(exercise).clamp(0, total).toInt();
    totalExercises += 1;
    totalSets += total;
    completedSets += completed;
    if (completed >= total) completedExercises += 1;
  }

  return RoutineSetSummary(
    totalSets: totalSets,
    completedSets: completedSets,
    totalExercises: totalExercises,
    completedExercises: completedExercises,
  );
}

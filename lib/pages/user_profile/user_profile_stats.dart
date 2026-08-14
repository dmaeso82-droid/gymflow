part of '../user_profile_page.dart';

class UserProfileStats {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> logs;
  final Set<DateTime> trainingDays;
  final Set<String> exercises;
  final List<Map<String, dynamic>> records;
  final double totalVolume;

  const UserProfileStats({
    required this.logs,
    required this.trainingDays,
    required this.exercises,
    required this.records,
    required this.totalVolume,
  });
}

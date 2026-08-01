int routineProgress(List<dynamic> exercises) {
  if (exercises.isEmpty) return 0;

  final done = exercises.where((item) {
    final map = Map<String, dynamic>.from(item as Map);
    return map['done'] == true;
  }).length;

  return ((done / exercises.length) * 100).round();
}

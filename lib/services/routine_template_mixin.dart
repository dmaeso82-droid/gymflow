part of 'trainer_routine_service.dart';

mixin RoutineTemplateMixin {
  CollectionReference<Map<String, dynamic>> get customTemplatesRef;

  String cleanGeneratedRoutineTitle(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return 'Rutina';
    if (raw.contains('·')) {
      final last = raw.split('·').last.trim();
      if (last.isNotEmpty) return last;
    }
    final cleanup = raw
        .replaceAll(RegExp(r'Hipertrofia\s*\d+D', caseSensitive: false), '')
        .replaceAll(RegExp(r'Fuerza\s*\d+D', caseSensitive: false), '')
        .replaceAll(RegExp(r'Definición\s*\d+D', caseSensitive: false), '')
        .replaceAll(RegExp(r'Pérdida\s*\d+D', caseSensitive: false), '')
        .replaceAll(RegExp(r'Principiante|Intermedio|Avanzado', caseSensitive: false), '')
        .replaceAll('·', '')
        .trim();
    return cleanup.isEmpty ? raw : cleanup;
  }

  String templateDisplayName(Map<String, dynamic> template, String source) {
    final name = template['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final objective = template['objective']?.toString() ?? 'Plantilla';
    final frequency = template['frequency']?.toString() ?? '-';
    return source == 'system'
        ? '$objective ${frequency}D'
        : '$objective ${frequency}D personalizada';
  }

  List<Map<String, dynamic>> exerciseMapsFromDynamicList(List<dynamic> exercises) {
    return exercises.whereType<Map>().map((item) {
      return RoutineExerciseModel.fromMap(Map<String, dynamic>.from(item)).toMap();
    }).toList();
  }

  Future<List<Map<String, dynamic>>> loadAutomaticTemplateOptions() async {
    final options = <Map<String, dynamic>>[];
    for (final objective in templateObjectives()) {
      for (final frequency in templateFrequenciesForObjective(objective)) {
        for (final level in templateLevelsForObjectiveAndFrequency(objective, frequency)) {
          final template = findRoutineTemplate(
            objective: objective,
            frequency: frequency,
            level: level,
          );
          if (template == null) continue;
          options.add({
            'id': 'system_${objective}_${frequency}_$level',
            'source': 'system',
            'name': templateDisplayName(template, 'system'),
            'template': template,
          });
        }
      }
    }
    final customSnapshot = await customTemplatesRef.orderBy('createdAt', descending: true).get();
    for (final doc in customSnapshot.docs) {
      final data = doc.data();
      final days = data['days'];
      if (days is! List || days.isEmpty) continue;
      options.insert(0, {
        'id': doc.id,
        'source': 'custom',
        'name': templateDisplayName(data, 'custom'),
        'template': {...data, 'id': doc.id},
      });
    }
    return options;
  }
}

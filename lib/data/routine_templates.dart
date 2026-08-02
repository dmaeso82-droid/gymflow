
const List<String> routineObjectives = ['Hipertrofia', 'Fuerza', 'Pérdida de grasa'];
const List<int> routineFrequencies = [3, 4, 5];
const List<String> routineLevels = ['Principiante', 'Intermedio', 'Avanzado'];

int dayOrder(String day) {
  switch (day) {
    case 'Lunes':
      return 1;
    case 'Martes':
      return 2;
    case 'Miércoles':
      return 3;
    case 'Jueves':
      return 4;
    case 'Viernes':
      return 5;
    case 'Sábado':
      return 6;
    case 'Domingo':
      return 7;
    default:
      return 99;
  }
}

List<String> templateDaysForFrequency(int frequency) {
  if (frequency == 5) return ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];
  if (frequency == 4) return ['Lunes', 'Martes', 'Jueves', 'Viernes'];
  return ['Lunes', 'Miércoles', 'Viernes'];
}

Map<String, String> levelConfig(String level) {
  if (level == 'Principiante') {
    return {
      'mainSets': '3',
      'accessorySets': '2',
      'hypertrophyReps': '10-12',
      'strengthReps': '5-6',
      'accessoryReps': '12-15',
      'mainRest': '90 s',
      'strengthRest': '150 s',
    };
  }

  if (level == 'Avanzado') {
    return {
      'mainSets': '5',
      'accessorySets': '4',
      'hypertrophyReps': '6-10',
      'strengthReps': '3-5',
      'accessoryReps': '10-15',
      'mainRest': '120 s',
      'strengthRest': '180 s',
    };
  }

  return {
    'mainSets': '4',
    'accessorySets': '3',
    'hypertrophyReps': '8-12',
    'strengthReps': '4-6',
    'accessoryReps': '10-15',
    'mainRest': '90 s',
    'strengthRest': '180 s',
  };
}

Map<String, dynamic> exercise(String name, String sets, String reps, String rest) {
  return {
    'name': name,
    'sets': int.tryParse(sets) ?? 3,
    'reps': reps,
    'weight': '',
    'rest': rest,
  };
}

List<String> labelsForTemplate(String objective, int frequency) {
  if (objective == 'Hipertrofia') {
    if (frequency == 3) return ['Torso', 'Pierna', 'Full body'];
    if (frequency == 4) return ['Pecho y tríceps', 'Espalda y bíceps', 'Pierna', 'Hombro y core'];
    return ['Pecho y tríceps', 'Espalda y bíceps', 'Pierna', 'Hombro y core', 'Full body'];
  }

  if (objective == 'Fuerza') {
    if (frequency == 3) return ['Sentadilla', 'Press banca', 'Peso muerto'];
    if (frequency == 4) return ['Sentadilla', 'Press banca', 'Peso muerto', 'Press militar'];
    return ['Sentadilla', 'Press banca', 'Peso muerto', 'Press militar', 'Full body fuerza'];
  }

  if (frequency == 3) return ['Full body A', 'Cardio y core', 'Full body B'];
  if (frequency == 4) return ['Full body A', 'Cardio y core', 'Full body B', 'Funcional'];
  return ['Full body A', 'Cardio y core', 'Full body B', 'Funcional', 'Cardio suave'];
}

List<Map<String, dynamic>> buildExercises(String objective, String label, String level) {
  final config = levelConfig(level);
  final mainSets = config['mainSets']!;
  final accessorySets = config['accessorySets']!;

  if (objective == 'Fuerza') {
    final mainReps = config['strengthReps']!;
    final accessoryReps = config['accessoryReps']!;
    final rest = config['strengthRest']!;

    if (label == 'Sentadilla') {
      return [
        exercise('Sentadilla trasera', mainSets, mainReps, rest),
        exercise('Prensa de piernas', accessorySets, accessoryReps, '120 s'),
        exercise('Peso muerto rumano', accessorySets, accessoryReps, '120 s'),
        exercise('Plancha frontal', '3', '45-60 s', '60 s'),
      ];
    }
    if (label == 'Press banca') {
      return [
        exercise('Press banca con barra', mainSets, mainReps, rest),
        exercise('Press inclinado con mancuernas', accessorySets, accessoryReps, '120 s'),
        exercise('Remo con barra', accessorySets, accessoryReps, '150 s'),
        exercise('Extensión tríceps en polea con barra', accessorySets, '8-10', '90 s'),
      ];
    }
    if (label == 'Peso muerto') {
      return [
        exercise('Peso muerto convencional', mainSets, mainReps, rest),
        exercise('Dominadas pronas', accessorySets, accessoryReps, '150 s'),
        exercise('Jalón de pecho', accessorySets, accessoryReps, '120 s'),
        exercise('Curl bíceps con barra Z', accessorySets, '8-10', '90 s'),
      ];
    }
    if (label == 'Press militar') {
      return [
        exercise('Press militar con barra', mainSets, mainReps, rest),
        exercise('Press banca agarre cerrado', accessorySets, accessoryReps, '120 s'),
        exercise('Elevaciones laterales con mancuernas', accessorySets, '10-15', '60 s'),
        exercise('Face pull', accessorySets, '12-15', '60 s'),
      ];
    }
    return [
      exercise('Sentadilla frontal', accessorySets, accessoryReps, '120 s'),
      exercise('Press banca con barra', accessorySets, accessoryReps, '120 s'),
      exercise('Remo con barra', accessorySets, accessoryReps, '120 s'),
      exercise('Peso muerto rumano', accessorySets, accessoryReps, '120 s'),
    ];
  }

  if (objective == 'Pérdida de grasa') {
    if (label == 'Cardio y core') {
      return [
        exercise('Cinta de correr', '1', '20-30 min', '-'),
        exercise('Russian twist', '3', '16-20', '45 s'),
        exercise('Mountain climbers', '3', '30-40 s', '45 s'),
        exercise('Pallof press', '3', '10-12/lado', '45 s'),
      ];
    }
    if (label == 'Funcional') {
      return [
        exercise('Kettlebell swing', mainSets, '12-15', '60 s'),
        exercise('Farmer walk', accessorySets, '30-40 m', '60 s'),
        exercise('Battle ropes', accessorySets, '20-30 s', '45 s'),
        exercise('Ab wheel', accessorySets, '8-12', '60 s'),
      ];
    }
    if (label == 'Cardio suave') {
      return [
        exercise('Bicicleta estática', '1', '25-35 min', '-'),
        exercise('Dead bug', '3', '10-12/lado', '45 s'),
        exercise('Plancha lateral', '3', '25-40 s/lado', '45 s'),
        exercise('Saltar a la comba', '4', '45-60 s', '45 s'),
      ];
    }
    return [
      exercise('Sentadilla goblet', mainSets, '12-15', '60 s'),
      exercise('Press banca con mancuernas', accessorySets, '10-12', '60 s'),
      exercise('Jalón de pecho', accessorySets, '10-12', '60 s'),
      exercise('Plancha frontal', '3', '30-45 s', '45 s'),
      exercise(label == 'Full body B' ? 'Elíptica' : 'Bicicleta estática', '1', '15-20 min', '-'),
    ];
  }

  final mainReps = config['hypertrophyReps']!;
  final accessoryReps = config['accessoryReps']!;
  final rest = config['mainRest']!;

  if (label == 'Pecho y tríceps') {
    return [
      exercise('Press banca con barra', mainSets, mainReps, rest),
      exercise('Press inclinado con mancuernas', accessorySets, mainReps, rest),
      exercise('Aperturas en peck deck', accessorySets, accessoryReps, '60 s'),
      exercise('Fondos en paralelas para pecho', accessorySets, mainReps, '90 s'),
      exercise('Extensión tríceps en polea con cuerda', accessorySets, accessoryReps, '60 s'),
    ];
  }
  if (label == 'Espalda y bíceps') {
    return [
      exercise('Dominadas pronas', mainSets, mainReps, rest),
      exercise('Jalón de pecho', accessorySets, mainReps, rest),
      exercise('Remo con barra', accessorySets, mainReps, rest),
      exercise('Face pull', accessorySets, accessoryReps, '60 s'),
      exercise('Curl martillo', accessorySets, accessoryReps, '60 s'),
    ];
  }
  if (label == 'Pierna') {
    return [
      exercise('Sentadilla trasera', mainSets, mainReps, '120 s'),
      exercise('Prensa de piernas', accessorySets, mainReps, rest),
      exercise('Peso muerto rumano', accessorySets, mainReps, rest),
      exercise('Curl femoral sentado', accessorySets, accessoryReps, '60 s'),
      exercise('Elevación de gemelos sentado', accessorySets, '12-20', '60 s'),
    ];
  }
  if (label == 'Hombro y core') {
    return [
      exercise('Press militar con barra', mainSets, mainReps, rest),
      exercise('Elevaciones laterales con mancuernas', accessorySets, accessoryReps, '60 s'),
      exercise('Pájaros con mancuernas', accessorySets, accessoryReps, '60 s'),
      exercise('Encogimientos con mancuernas', accessorySets, '10-15', '75 s'),
      exercise('Ab wheel', accessorySets, '8-12', '60 s'),
    ];
  }
  if (label == 'Torso') {
    return [
      exercise('Press banca con barra', mainSets, mainReps, rest),
      exercise('Jalón de pecho', mainSets, mainReps, rest),
      exercise('Press militar con mancuernas', accessorySets, mainReps, '75 s'),
      exercise('Remo en polea baja', accessorySets, mainReps, '75 s'),
      exercise('Curl bíceps con barra Z', accessorySets, accessoryReps, '60 s'),
      exercise('Extensión tríceps en polea con cuerda', accessorySets, accessoryReps, '60 s'),
    ];
  }
  return [
    exercise('Press banca con mancuernas', accessorySets, mainReps, rest),
    exercise('Remo en polea baja', accessorySets, mainReps, rest),
    exercise('Sentadilla goblet', accessorySets, mainReps, rest),
    exercise('Hip thrust con barra', accessorySets, mainReps, rest),
    exercise('Plancha frontal', '3', '30-60 s', '45 s'),
  ];
}

Map<String, dynamic> buildTemplate(String objective, int frequency, String level) {
  final days = templateDaysForFrequency(frequency);
  final labels = labelsForTemplate(objective, frequency);
  final templateDays = <Map<String, dynamic>>[];

  for (var index = 0; index < days.length; index++) {
    final day = days[index];
    final label = labels[index];
    templateDays.add({
      'day': day,
      'dayOrder': dayOrder(day),
      'title': '$objective ${frequency}D · $label',
      'notes': 'Rutina generada automáticamente. Objetivo: $objective. Nivel: $level. Frecuencia: $frequency días.',
      'exercises': buildExercises(objective, label, level),
    });
  }

  templateDays.sort((a, b) => (a['dayOrder'] as int).compareTo(b['dayOrder'] as int));

  return {
    'objective': objective,
    'frequency': frequency,
    'level': level,
    'days': templateDays,
  };
}

List<String> templateObjectives() => routineObjectives;
List<int> templateFrequenciesForObjective(String objective) => routineFrequencies;
List<String> templateLevelsForObjectiveAndFrequency(String objective, int frequency) => routineLevels;

Map<String, dynamic>? findRoutineTemplate({
  required String objective,
  required int frequency,
  required String level,
}) {
  if (!routineObjectives.contains(objective)) return null;
  if (!routineFrequencies.contains(frequency)) return null;
  if (!routineLevels.contains(level)) return null;
  return buildTemplate(objective, frequency, level);
}

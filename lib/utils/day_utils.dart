class DayUtils {
  static const weekDays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  static int order(String day) {
    final normalized = day
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');

    const aliases = {
      'lunes': 1,
      'martes': 2,
      'miercoles': 3,
      'jueves': 4,
      'viernes': 5,
      'sabado': 6,
      'domingo': 7,
    };

    return aliases[normalized] ?? 99;
  }

  static List<String> daysForFrequency(int frequency) {
    if (frequency <= 1) {
      return ['Lunes'];
    }

    if (frequency == 2) {
      return ['Lunes', 'Jueves'];
    }

    if (frequency == 3) {
      return ['Lunes', 'Miércoles', 'Viernes'];
    }

    if (frequency == 4) {
      return ['Lunes', 'Martes', 'Jueves', 'Viernes'];
    }

    if (frequency == 5) {
      return ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];
    }

    if (frequency == 6) {
      return [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
      ];
    }

    return weekDays;
  }
}

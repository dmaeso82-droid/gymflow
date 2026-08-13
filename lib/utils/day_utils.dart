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
    final index = weekDays.indexOf(day);
    return index < 0 ? 99 : index + 1;
  }

  static List<String> daysForFrequency(int frequency) {
    if (frequency == 5) return ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];
    if (frequency == 4) return ['Lunes', 'Martes', 'Jueves', 'Viernes'];
    return ['Lunes', 'Miércoles', 'Viernes'];
  }
}

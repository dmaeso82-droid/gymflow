import 'package:cloud_firestore/cloud_firestore.dart';

class AppFormatters {
  static int intValue(dynamic value, {int fallback = 0, bool extractFirstNumber = false}) {
    if (value is int) return value;
    if (value is num) return value.round();
    final text = value?.toString() ?? '';
    if (extractFirstNumber) {
      final match = RegExp(r'-?\d+').firstMatch(text);
      return int.tryParse(match?.group(0) ?? '') ?? fallback;
    }
    return int.tryParse(text) ?? fallback;
  }

  static double doubleValue(dynamic value, {double fallback = 0.0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse((value?.toString() ?? '').replaceAll(',', '.')) ?? fallback;
  }

  static double? decimalValue(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  static int timestampSortValue(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return 0;
  }

  static String formatDate(dynamic value, {bool includeTime = false, String fallback = 'Fecha pendiente'}) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      if (!includeTime) return '$day/$month/$year';
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    }
    return fallback;
  }

  static String formatShortDate(dynamic value, {String fallback = '-'}) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      return '$day/$month';
    }
    return fallback;
  }

  static String formatNumber(num value, {String zeroFallback = '-'}) {
    if (value == 0 && zeroFallback.isNotEmpty) return zeroFallback;
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  static String formatCompact(num value) => formatNumber(value);

  static String formatWeight(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  static String formatKg(double value) => '${formatWeight(value)} kg';

  static String signedKg(double value) {
    if (value > 0) return '+${formatKg(value)}';
    if (value < 0) return '-${formatKg(value.abs())}';
    return '0 kg';
  }

  static bool isThisWeek(dynamic value) {
    if (value is! Timestamp) return false;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    final date = value.toDate();
    return !date.isBefore(startOfWeek) && date.isBefore(endOfWeek);
  }

  static bool isPreviousWeek(dynamic value) {
    if (value is! Timestamp) return false;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final startPreviousWeek = startOfWeek.subtract(const Duration(days: 7));
    final date = value.toDate();
    return !date.isBefore(startPreviousWeek) && date.isBefore(startOfWeek);
  }
}

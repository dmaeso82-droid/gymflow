
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../utils/app_formatters.dart';
import '../theme/app_theme.dart';

import '../widgets/app_card.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';

class ExerciseProgress extends StatefulWidget {
  final CollectionReference<Map<String, dynamic>> logsRef;
  final String userId;

  const ExerciseProgress({
    super.key,
    required this.logsRef,
    required this.userId,
  });

  @override
  State<ExerciseProgress> createState() => _ExerciseProgressState();
}

class _ExerciseProgressState extends State<ExerciseProgress> {
  String? selectedExercise;

double doubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse((value?.toString() ?? '').replaceAll(',', '.')) ?? 0.0;
  }

String signedKg(double value) {
    if (value > 0) return '+${AppFormatters.formatKg(value)}';
    if (value < 0) return '-${AppFormatters.formatKg(value.abs())}';
    return '0 kg';
  }

String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day/$month/$year';
    }
    return 'Fecha pendiente';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.logsRef.where('userId', isEqualTo: widget.userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppCard(child: Center(child: CircularProgressIndicator()));
        }

        final logs = snapshot.data?.docs ?? [];
        if (logs.isEmpty) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(icon: Icons.trending_up, title: 'Evolución por ejercicio'),
                SizedBox(height: 12),
                Text(
                  'Todavía no hay entrenamientos registrados para calcular evolución.',
                  style: TextStyle(color: context.gymMutedText),
                ),
              ],
            ),
          );
        }

        final groupedLogs = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
        for (final doc in logs) {
          final data = doc.data();
          final exercise = data['exercise']?.toString().trim() ?? '';
          if (exercise.isEmpty) continue;
          groupedLogs.putIfAbsent(exercise, () => []).add(doc);
        }

        final exerciseNames = groupedLogs.keys.toList()..sort();
        if (exerciseNames.isEmpty) {
          return AppCard(child: Text('Todavía no hay ejercicios registrados.'));
        }

        if (selectedExercise == null || !exerciseNames.contains(selectedExercise)) {
          selectedExercise = exerciseNames.first;
        }

        final progressItems = <Map<String, dynamic>>[];
        groupedLogs.forEach((exercise, docs) {
          docs.sort((a, b) {
            final aDate = AppFormatters.timestampSortValue(a.data()['createdAt']);
            final bDate = AppFormatters.timestampSortValue(b.data()['createdAt']);
            return aDate.compareTo(bDate);
          });

          final first = docs.first.data();
          final latest = docs.last.data();
          Map<String, dynamic> best = first;
          final points = <Map<String, dynamic>>[];

          for (var index = 0; index < docs.length; index++) {
            final data = docs[index].data();
            final weight = AppFormatters.doubleValue(data['weight']);
            final reps = AppFormatters.intValue(data['reps']);
            final bestWeight = AppFormatters.doubleValue(best['weight']);
            final bestReps = AppFormatters.intValue(best['reps']);

            points.add({
              'x': index.toDouble(),
              'weight': weight,
              'reps': reps,
              'createdAt': data['createdAt'],
            });

            if (weight > bestWeight || (weight == bestWeight && reps > bestReps)) {
              best = data;
            }
          }

          final firstWeight = AppFormatters.doubleValue(first['weight']);
          final latestWeight = AppFormatters.doubleValue(latest['weight']);
          final bestWeight = AppFormatters.doubleValue(best['weight']);
          final latestReps = AppFormatters.intValue(latest['reps']);
          final bestReps = AppFormatters.intValue(best['reps']);
          final weightDelta = latestWeight - firstWeight;

          progressItems.add({
            'exercise': exercise,
            'firstWeight': firstWeight,
            'latestWeight': latestWeight,
            'latestReps': latestReps,
            'bestWeight': bestWeight,
            'bestReps': bestReps,
            'weightDelta': weightDelta,
            'series': docs.length,
            'latestDate': latest['createdAt'],
            'routineTitle': latest['routineTitle']?.toString() ?? 'Rutina',
            'points': points,
          });
        });

        progressItems.sort((a, b) {
          final deltaCompare = AppFormatters.doubleValue(b['weightDelta']).compareTo(AppFormatters.doubleValue(a['weightDelta']));
          if (deltaCompare != 0) return deltaCompare;
          final bestCompare = AppFormatters.doubleValue(b['bestWeight']).compareTo(AppFormatters.doubleValue(a['bestWeight']));
          if (bestCompare != 0) return bestCompare;
          return a['exercise'].toString().compareTo(b['exercise'].toString());
        });

        final improvedCount = progressItems.where((item) => AppFormatters.doubleValue(item['weightDelta']) > 0).length;
        final bestProgress = progressItems.isEmpty ? null : progressItems.first;
        final bestProgressText = bestProgress == null
            ? '-'
            : '${bestProgress['exercise']} ${AppFormatters.signedKg(AppFormatters.doubleValue(bestProgress['weightDelta']))}';

        final selectedItem = progressItems.firstWhere(
          (item) => item['exercise'] == selectedExercise,
          orElse: () => progressItems.first,
        );

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(icon: Icons.trending_up, title: 'Evolución por ejercicio'),
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoChip(text: '$improvedCount ejercicios mejorando'),
                  InfoChip(text: 'Mayor progreso: $bestProgressText'),
                ],
              ),
              SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: selectedExercise,
                dropdownColor: context.gymSurface,
                decoration: InputDecoration(
                  labelText: 'Ejercicio',
                  border: OutlineInputBorder(),
                ),
                items: exerciseNames.map((exercise) {
                  return DropdownMenuItem(value: exercise, child: Text(exercise));
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => selectedExercise = value);
                },
              ),
              SizedBox(height: 14),
              ExerciseProgressDetail(
                item: selectedItem,
                formatKg: AppFormatters.formatKg,
                signedKg: AppFormatters.signedKg,
                formatDate: AppFormatters.formatDate,
                doubleValue: AppFormatters.doubleValue,
                intValue: AppFormatters.intValue,
              ),
            ],
          ),
        );
      },
    );
  }
}

class ExerciseProgressDetail extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(double value) formatKg;
  final String Function(double value) signedKg;
  final String Function(dynamic value) formatDate;
  final double Function(dynamic value) doubleValue;
  final int Function(dynamic value) intValue;

  const ExerciseProgressDetail({
    super.key,
    required this.item,
    required this.formatKg,
    required this.signedKg,
    required this.formatDate,
    required this.doubleValue,
    required this.intValue,
  });

  @override
  Widget build(BuildContext context) {
    final exercise = item['exercise']?.toString() ?? 'Ejercicio';
    final latestWeight = AppFormatters.doubleValue(item['latestWeight']);
    final latestReps = AppFormatters.intValue(item['latestReps']);
    final bestWeight = AppFormatters.doubleValue(item['bestWeight']);
    final bestReps = AppFormatters.intValue(item['bestReps']);
    final weightDelta = AppFormatters.doubleValue(item['weightDelta']);
    final series = AppFormatters.intValue(item['series']);
    final routineTitle = item['routineTitle']?.toString() ?? 'Rutina';
    final latestDate = AppFormatters.formatDate(item['latestDate']);
    final isImproving = weightDelta > 0;
    final points = List<Map<String, dynamic>>.from(item['points'] ?? []);

    return Container(
      decoration: BoxDecoration(
        color: context.gymSubtleSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.gymBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (isImproving ? context.gymFitnessAccent : context.gymMutedText).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isImproving ? Icons.trending_up : Icons.trending_flat,
                  color: isImproving ? context.gymFitnessAccent : context.gymMutedText,
                ),
              ),
              title: Text(exercise, style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(routineTitle, style: TextStyle(color: context.gymMutedText)),
                    SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        InfoChip(text: 'Actual ${AppFormatters.formatKg(latestWeight)} x $latestReps'),
                        InfoChip(text: 'Progreso ${AppFormatters.signedKg(weightDelta)}'),
                        InfoChip(text: 'Mejor ${AppFormatters.formatKg(bestWeight)} x $bestReps'),
                        InfoChip(text: '$series series'),
                        InfoChip(text: latestDate),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (points.length >= 2) ...[
              SizedBox(height: 10),
              SizedBox(height: 180, child: ExerciseLineChart(points: points, formatKg: formatKg)),
            ] else ...[
              SizedBox(height: 8),
              Text(
                'Registra al menos 2 series para ver la gráfica de evolución.',
                style: TextStyle(color: context.gymMutedText, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ExerciseLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> points;
  final String Function(double value) formatKg;

  const ExerciseLineChart({super.key, required this.points, required this.formatKg});

@override
  Widget build(BuildContext context) {
    final spots = points.map((point) => FlSpot(AppFormatters.doubleValue(point['x']), AppFormatters.doubleValue(point['weight']))).toList();
    final weights = spots.map((spot) => spot.y).toList();
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);
    final rangePadding = (maxWeight - minWeight).abs() < 1 ? 5.0 : 2.0;
    final minY = (minWeight - rangePadding).clamp(0, double.infinity).toDouble();
    final maxY = maxWeight + rangePadding;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: context.gymBorder, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                return Text(AppFormatters.formatKg(value), style: TextStyle(color: context.gymMutedText, fontSize: 10));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: context.gymBorder)),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: context.gymFitnessAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: context.gymFitnessAccent.withValues(alpha: 0.12)),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.round();
                final reps = index >= 0 && index < points.length ? points[index]['reps']?.toString() ?? '-' : '-';
                return LineTooltipItem(
                  '${AppFormatters.formatKg(spot.y)} x $reps',
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}




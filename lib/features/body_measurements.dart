
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';

class BodyMeasurementsPanel extends StatefulWidget {
  final String gymId;
  final String filterField;
  final String filterValue;
  final String title;
  final String emptyText;
  final bool allowAdd;
  final String? userId;
  final String? userName;
  final String? userEmail;

  const BodyMeasurementsPanel({
    super.key,
    required this.gymId,
    required this.filterField,
    required this.filterValue,
    required this.title,
    required this.emptyText,
    this.allowAdd = false,
    this.userId,
    this.userName,
    this.userEmail,
  });

  @override
  State<BodyMeasurementsPanel> createState() => _BodyMeasurementsPanelState();
}

class _BodyMeasurementsPanelState extends State<BodyMeasurementsPanel> {
  String selectedMetric = 'bodyWeight';

  CollectionReference<Map<String, dynamic>> get measurementsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('body_measurements');

  static const metricLabels = <String, String>{
    'bodyWeight': 'Peso corporal',
    'waist': 'Cintura',
    'chest': 'Pecho',
    'arm': 'Brazo',
    'leg': 'Pierna',
  };

  static const metricUnits = <String, String>{
    'bodyWeight': 'kg',
    'waist': 'cm',
    'chest': 'cm',
    'arm': 'cm',
    'leg': 'cm',
  };

  double doubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  int timestampSortValue(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return 0;
  }

  String formatNumber(double value) {
    if (value == 0) return '-';
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  String signedValue(double value, String unit) {
    if (value > 0) return '+${formatNumber(value)} $unit';
    if (value < 0) return '${formatNumber(value)} $unit';
    return '0 $unit';
  }

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    }
    return 'Fecha pendiente';
  }

  String formatShortDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      return '$day/$month';
    }
    return '-';
  }

  Future<void> showMeasurementDialog(BuildContext context) async {
    final weightController = TextEditingController();
    final waistController = TextEditingController();
    final chestController = TextEditingController();
    final armController = TextEditingController();
    final legController = TextEditingController();

    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Registrar medidas'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: weightController,
                  label: 'Peso corporal (kg)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: waistController,
                  label: 'Cintura (cm)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: chestController,
                  label: 'Pecho (cm)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: armController,
                  label: 'Brazo (cm)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: legController,
                  label: 'Pierna (cm)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                final weight = double.tryParse(weightController.text.trim().replaceAll(',', '.')) ?? 0;
                final waist = double.tryParse(waistController.text.trim().replaceAll(',', '.')) ?? 0;
                final chest = double.tryParse(chestController.text.trim().replaceAll(',', '.')) ?? 0;
                final arm = double.tryParse(armController.text.trim().replaceAll(',', '.')) ?? 0;
                final leg = double.tryParse(legController.text.trim().replaceAll(',', '.')) ?? 0;

                if (weight <= 0 && waist <= 0 && chest <= 0 && arm <= 0 && leg <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Introduce al menos una medida válida.')),
                  );
                  return;
                }

                Navigator.pop(dialogContext, {
                  'bodyWeight': weight,
                  'waist': waist,
                  'chest': chest,
                  'arm': arm,
                  'leg': leg,
                });
              },
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    weightController.dispose();
    waistController.dispose();
    chestController.dispose();
    armController.dispose();
    legController.dispose();

    if (result == null) return;

    await measurementsRef.add({
      'userId': widget.userId ?? '',
      'userName': widget.userName ?? '',
      'userEmail': (widget.userEmail ?? '').toLowerCase(),
      'bodyWeight': result['bodyWeight'],
      'waist': result['waist'],
      'chest': result['chest'],
      'arm': result['arm'],
      'leg': result['leg'],
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medidas guardadas.')),
      );
    }
  }

  Future<void> deleteMeasurement(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Eliminar medida'),
          content: const Text('¿Seguro que quieres eliminar este registro de medidas? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    await measurementsRef.doc(doc.id).delete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medida eliminada.')),
      );
    }
  }

  List<Map<String, dynamic>> chartPoints(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> measurements,
    String metric,
  ) {
    final ordered = [...measurements];
    ordered.sort((a, b) => timestampSortValue(a.data()['createdAt']).compareTo(timestampSortValue(b.data()['createdAt'])));

    final points = <Map<String, dynamic>>[];
    for (final doc in ordered) {
      final data = doc.data();
      final value = doubleValue(data[metric]);
      if (value <= 0) continue;
      points.add({
        'x': points.length.toDouble(),
        'value': value,
        'createdAt': data['createdAt'],
      });
    }
    return points;
  }


  bool matchesMeasurement(Map<String, dynamic> data, String normalizedValue) {
    final configuredFieldValue = (data[widget.filterField] ?? '').toString().toLowerCase().trim();
    final storedUserEmail = (data['userEmail'] ?? '').toString().toLowerCase().trim();
    final storedUserId = (data['userId'] ?? '').toString().trim();
    final widgetUserEmail = (widget.userEmail ?? '').toString().toLowerCase().trim();
    final widgetUserId = (widget.userId ?? '').toString().trim();

    return configuredFieldValue == normalizedValue ||
        (widgetUserEmail.isNotEmpty && storedUserEmail == widgetUserEmail) ||
        (widgetUserId.isNotEmpty && storedUserId == widgetUserId);
  }

  @override
  Widget build(BuildContext context) {
    final normalizedValue = widget.filterValue.trim().toLowerCase();
    if (normalizedValue.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(icon: Icons.monitor_weight, title: widget.title),
            const SizedBox(height: 12),
            const Text(
              'No hay identificador suficiente para cargar medidas.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: measurementsRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppCard(child: Center(child: CircularProgressIndicator()));
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> measurements =
            List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.data?.docs ?? [])
                .where((doc) => matchesMeasurement(doc.data(), normalizedValue))
                .toList();
        measurements.sort((a, b) {
          final aDate = timestampSortValue(a.data()['createdAt']);
          final bDate = timestampSortValue(b.data()['createdAt']);
          return bDate.compareTo(aDate);
        });

        if (measurements.isEmpty) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(icon: Icons.monitor_weight, title: widget.title),
                const SizedBox(height: 12),
                Text(widget.emptyText, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                const SectionTitle(icon: Icons.show_chart, title: 'Evolución corporal'),
                const SizedBox(height: 8),
                const Text(
                  'Registra al menos 2 mediciones para ver la gráfica de evolución corporal.',
                  style: TextStyle(color: Colors.white70),
                ),
                if (widget.allowAdd) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => showMeasurementDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Registrar medidas'),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        final latest = measurements.first.data();
        final first = measurements.last.data();
        final latestWeight = doubleValue(latest['bodyWeight']);
        final firstWeight = doubleValue(first['bodyWeight']);
        final latestWaist = doubleValue(latest['waist']);
        final firstWaist = doubleValue(first['waist']);
        final weightDelta = latestWeight - firstWeight;
        final waistDelta = latestWaist - firstWaist;
        final latestDate = formatDate(latest['createdAt']);
        final recent = measurements.take(5).toList();
        final metricLabel = metricLabels[selectedMetric] ?? 'Medida';
        final metricUnit = metricUnits[selectedMetric] ?? '';
        final points = chartPoints(measurements, selectedMetric);
        final firstMetric = points.isEmpty ? 0.0 : doubleValue(points.first['value']);
        final latestMetric = points.isEmpty ? 0.0 : doubleValue(points.last['value']);
        final metricDelta = latestMetric - firstMetric;

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(icon: Icons.monitor_weight, title: widget.title),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoChip(text: '${measurements.length} registros'),
                  if (latestWeight > 0) InfoChip(text: 'Peso ${formatNumber(latestWeight)} kg'),
                  if (measurements.length > 1 && latestWeight > 0 && firstWeight > 0)
                    InfoChip(text: 'Cambio peso ${signedValue(weightDelta, 'kg')}'),
                  if (latestWaist > 0) InfoChip(text: 'Cintura ${formatNumber(latestWaist)} cm'),
                  if (measurements.length > 1 && latestWaist > 0 && firstWaist > 0)
                    InfoChip(text: 'Cambio cintura ${signedValue(waistDelta, 'cm')}'),
                  InfoChip(text: 'Último: $latestDate'),
                ],
              ),
              if (widget.allowAdd) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => showMeasurementDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Registrar nuevas medidas'),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const SectionTitle(icon: Icons.show_chart, title: 'Evolución corporal'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedMetric,
                dropdownColor: const Color(0xFF0F172A),
                decoration: const InputDecoration(
                  labelText: 'Métrica',
                  border: OutlineInputBorder(),
                ),
                items: metricLabels.entries.map((entry) {
                  return DropdownMenuItem(value: entry.key, child: Text(entry.value));
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => selectedMetric = value);
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (latestMetric > 0) InfoChip(text: '$metricLabel actual ${formatNumber(latestMetric)} $metricUnit'),
                  if (points.length > 1) InfoChip(text: 'Cambio ${signedValue(metricDelta, metricUnit)}'),
                  InfoChip(text: '${points.length} puntos'),
                ],
              ),
              const SizedBox(height: 12),
              if (points.length >= 2)
                SizedBox(
                  height: 190,
                  child: BodyMetricLineChart(
                    points: points,
                    unit: metricUnit,
                    formatNumber: formatNumber,
                    formatDate: formatShortDate,
                  ),
                )
              else
                const Text(
                  'Registra al menos 2 valores de esta métrica para ver la gráfica.',
                  style: TextStyle(color: Colors.white70),
                ),
              const SizedBox(height: 18),
              const Text(
                'Historial de medidas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ...recent.map((doc) {
                final data = doc.data();
                final bodyWeight = doubleValue(data['bodyWeight']);
                final waist = doubleValue(data['waist']);
                final chest = doubleValue(data['chest']);
                final arm = doubleValue(data['arm']);
                final leg = doubleValue(data['leg']);
                final date = formatDate(data['createdAt']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF020617),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.straighten, color: Colors.greenAccent),
                    ),
                    title: Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (bodyWeight > 0) InfoChip(text: '${formatNumber(bodyWeight)} kg'),
                          if (waist > 0) InfoChip(text: 'Cintura ${formatNumber(waist)} cm'),
                          if (chest > 0) InfoChip(text: 'Pecho ${formatNumber(chest)} cm'),
                          if (arm > 0) InfoChip(text: 'Brazo ${formatNumber(arm)} cm'),
                          if (leg > 0) InfoChip(text: 'Pierna ${formatNumber(leg)} cm'),
                        ],
                      ),
                    ),
                    trailing: widget.allowAdd
                        ? IconButton(
                            tooltip: 'Eliminar medida',
                            onPressed: () => deleteMeasurement(context, doc),
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          )
                        : null,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class BodyMetricLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> points;
  final String unit;
  final String Function(double value) formatNumber;
  final String Function(dynamic value) formatDate;

  const BodyMetricLineChart({
    super.key,
    required this.points,
    required this.unit,
    required this.formatNumber,
    required this.formatDate,
  });

  double doubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final spots = points.map((point) => FlSpot(doubleValue(point['x']), doubleValue(point['value']))).toList();
    final values = spots.map((spot) => spot.y).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final rangePadding = (maxValue - minValue).abs() < 1 ? 2.0 : 1.5;
    final minY = (minValue - rangePadding).clamp(0, double.infinity).toDouble();
    final maxY = maxValue + rangePadding;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withOpacity(0.08),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= points.length) return const SizedBox.shrink();
                return Text(
                  formatDate(points[index]['createdAt']),
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${formatNumber(value)}$unit',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.white10)),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.greenAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.greenAccent.withOpacity(0.12),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.round();
                final date = index >= 0 && index < points.length ? formatDate(points[index]['createdAt']) : '-';
                return LineTooltipItem(
                  '${formatNumber(spot.y)} $unit\n$date',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

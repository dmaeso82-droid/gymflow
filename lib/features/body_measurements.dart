
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../utils/app_formatters.dart';
import '../theme/app_theme.dart';

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

  CollectionReference<Map<String, dynamic>> get activityRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('activity');

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

int timestampSortValue(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return 0;
  }

String signedValue(double value, String unit) {
    if (value > 0) return '+${AppFormatters.formatNumber(value)} $unit';
    if (value < 0) return '${AppFormatters.formatNumber(value)} $unit';
    return '0 $unit';
  }

Future<Map<String,String>> currentActor() async {
    final user=FirebaseAuth.instance.currentUser;
    if(user==null) return {'uid':'','name':'Sistema','email':''};
    return {
      'uid':user.uid,
      'name':(user.displayName?.isNotEmpty==true?user.displayName!:user.email??'Entrenador'),
      'email':user.email??'',
    };
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
          backgroundColor: context.gymSurface,
          title: Text('Registrar medidas'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: weightController,
                  label: 'Peso corporal (kg)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 12),
                AppTextField(
                  controller: waistController,
                  label: 'Cintura (cm)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 12),
                AppTextField(
                  controller: chestController,
                  label: 'Pecho (cm)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 12),
                AppTextField(
                  controller: armController,
                  label: 'Brazo (cm)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 12),
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
              child: Text('Cancelar'),
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
              icon: Icon(Icons.save),
              label: Text('Guardar'),
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

    final actor = await currentActor();
    final docRef = measurementsRef.doc();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(docRef, {
      'userId': widget.userId ?? '',
      'userName': widget.userName ?? '',
      'userEmail': (widget.userEmail ?? '').toLowerCase(),
      'bodyWeight': result['bodyWeight'],
      'waist': result['waist'],
      'chest': result['chest'],
      'arm': result['arm'],
      'leg': result['leg'],
      'recordedBy': actor['name'],
      'recordedByUid': actor['uid'],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(activityRef.doc(), {
      'type':'measurement_created','target':widget.userName ?? '',
      'targetId':docRef.id,'user':actor['name'],'userUid':actor['uid'],
      'createdAt':FieldValue.serverTimestamp()
    });
    await batch.commit();

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
          backgroundColor: context.gymSurface,
          title: Text('Eliminar medida'),
          content: Text('¿Seguro que quieres eliminar este registro de medidas? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancelar'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: Icon(Icons.delete_outline),
              label: Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    final actor = await currentActor();
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(measurementsRef.doc(doc.id));
    batch.set(activityRef.doc(), {
      'type':'measurement_deleted','target':widget.userName ?? '',
      'targetId':doc.id,'user':actor['name'],'userUid':actor['uid'],
      'createdAt':FieldValue.serverTimestamp()
    });
    await batch.commit();

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
    ordered.sort((a, b) => AppFormatters.timestampSortValue(a.data()['createdAt']).compareTo(AppFormatters.timestampSortValue(b.data()['createdAt'])));

    final points = <Map<String, dynamic>>[];
    for (final doc in ordered) {
      final data = doc.data();
      final value = AppFormatters.doubleValue(data[metric]);
      if (value <= 0) continue;
      points.add({
        'x': points.length.toDouble(),
        'value': value,
        'createdAt': data['createdAt'],
      });
    }
    return points;
  }



  Query<Map<String, dynamic>> scopedMeasurementsQuery(String normalizedValue) {
    if (widget.userId?.trim().isNotEmpty == true) {
      return measurementsRef.where('userId', isEqualTo: widget.userId!.trim());
    }
    if (widget.userEmail?.trim().isNotEmpty == true) {
      return measurementsRef.where('userEmail', isEqualTo: widget.userEmail!.trim().toLowerCase());
    }
    final value = widget.filterField.toLowerCase().contains('email') ? normalizedValue : widget.filterValue.trim();
    return measurementsRef.where(widget.filterField, isEqualTo: value);
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
            SizedBox(height: 12),
            Text(
              'No hay identificador suficiente para cargar medidas.',
              style: TextStyle(color: context.gymMutedText),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: scopedMeasurementsQuery(normalizedValue).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppCard(child: Center(child: CircularProgressIndicator()));
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> measurements =
            List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.data?.docs ?? [])
                .where((doc) => matchesMeasurement(doc.data(), normalizedValue))
                .toList();
        measurements.sort((a, b) {
          final aDate = AppFormatters.timestampSortValue(a.data()['createdAt']);
          final bDate = AppFormatters.timestampSortValue(b.data()['createdAt']);
          return bDate.compareTo(aDate);
        });

        if (measurements.isEmpty) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(icon: Icons.monitor_weight, title: widget.title),
                SizedBox(height: 12),
                Text(widget.emptyText, style: TextStyle(color: context.gymMutedText)),
                SizedBox(height: 12),
                SectionTitle(icon: Icons.show_chart, title: 'Evolución corporal'),
                SizedBox(height: 8),
                Text(
                  'Registra al menos 2 mediciones para ver la gráfica de evolución corporal.',
                  style: TextStyle(color: context.gymMutedText),
                ),
                if (widget.allowAdd) ...[
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => showMeasurementDialog(context),
                      icon: Icon(Icons.add),
                      label: Text('Registrar medidas'),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        final latest = measurements.first.data();
        final first = measurements.last.data();
        final latestWeight = AppFormatters.doubleValue(latest['bodyWeight']);
        final firstWeight = AppFormatters.doubleValue(first['bodyWeight']);
        final latestWaist = AppFormatters.doubleValue(latest['waist']);
        final firstWaist = AppFormatters.doubleValue(first['waist']);
        final weightDelta = latestWeight - firstWeight;
        final waistDelta = latestWaist - firstWaist;
        final latestDate = AppFormatters.formatDate(latest['createdAt']);
        final recent = measurements.take(5).toList();
        final metricLabel = metricLabels[selectedMetric] ?? 'Medida';
        final metricUnit = metricUnits[selectedMetric] ?? '';
        final points = chartPoints(measurements, selectedMetric);
        final firstMetric = points.isEmpty ? 0.0 : AppFormatters.doubleValue(points.first['value']);
        final latestMetric = points.isEmpty ? 0.0 : AppFormatters.doubleValue(points.last['value']);
        final metricDelta = latestMetric - firstMetric;

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(icon: Icons.monitor_weight, title: widget.title),
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoChip(text: '${measurements.length} registros'),
                  if (latestWeight > 0) InfoChip(text: 'Peso ${AppFormatters.formatNumber(latestWeight)} kg'),
                  if (measurements.length > 1 && latestWeight > 0 && firstWeight > 0)
                    InfoChip(text: 'Cambio peso ${signedValue(weightDelta, 'kg')}'),
                  if (latestWaist > 0) InfoChip(text: 'Cintura ${AppFormatters.formatNumber(latestWaist)} cm'),
                  if (measurements.length > 1 && latestWaist > 0 && firstWaist > 0)
                    InfoChip(text: 'Cambio cintura ${signedValue(waistDelta, 'cm')}'),
                  InfoChip(text: 'Último: $latestDate'),
                ],
              ),
              if (widget.allowAdd) ...[
                SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => showMeasurementDialog(context),
                    icon: Icon(Icons.add),
                    label: Text('Registrar nuevas medidas'),
                  ),
                ),
              ],
              SizedBox(height: 18),
              SectionTitle(icon: Icons.show_chart, title: 'Evolución corporal'),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedMetric,
                dropdownColor: context.gymSurface,
                decoration: InputDecoration(
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
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (latestMetric > 0) InfoChip(text: '$metricLabel actual ${AppFormatters.formatNumber(latestMetric)} $metricUnit'),
                  if (points.length > 1) InfoChip(text: 'Cambio ${signedValue(metricDelta, metricUnit)}'),
                  InfoChip(text: '${points.length} puntos'),
                ],
              ),
              SizedBox(height: 12),
              if (points.length >= 2)
                SizedBox(
                  height: 190,
                  child: BodyMetricLineChart(
                    points: points,
                    unit: metricUnit,
                    formatNumber: AppFormatters.formatNumber,
                    formatDate: AppFormatters.formatShortDate,
                  ),
                )
              else
                Text(
                  'Registra al menos 2 valores de esta métrica para ver la gráfica.',
                  style: TextStyle(color: context.gymMutedText),
                ),
              SizedBox(height: 18),
              Text(
                'Historial de medidas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 10),
              ...recent.map((doc) {
                final data = doc.data();
                final bodyWeight = AppFormatters.doubleValue(data['bodyWeight']);
                final waist = AppFormatters.doubleValue(data['waist']);
                final chest = AppFormatters.doubleValue(data['chest']);
                final arm = AppFormatters.doubleValue(data['arm']);
                final leg = AppFormatters.doubleValue(data['leg']);
                final date = AppFormatters.formatDate(data['createdAt']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: context.gymSubtleSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.gymBorder),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.gymFitnessAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.straighten, color: context.gymFitnessAccent),
                    ),
                    title: Text(date, style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (bodyWeight > 0) InfoChip(text: '${AppFormatters.formatNumber(bodyWeight)} kg'),
                          if (waist > 0) InfoChip(text: 'Cintura ${AppFormatters.formatNumber(waist)} cm'),
                          if (chest > 0) InfoChip(text: 'Pecho ${AppFormatters.formatNumber(chest)} cm'),
                          if (arm > 0) InfoChip(text: 'Brazo ${AppFormatters.formatNumber(arm)} cm'),
                          if (leg > 0) InfoChip(text: 'Pierna ${AppFormatters.formatNumber(leg)} cm'),
                          if ((data['recordedBy'] ?? '').toString().isNotEmpty)
                            InfoChip(text: 'Por ${data['recordedBy']}'),
                        ],
                      ),
                    ),
                    trailing: widget.allowAdd
                        ? IconButton(
                            tooltip: 'Eliminar medida',
                            onPressed: () => deleteMeasurement(context, doc),
                            icon: Icon(Icons.delete_outline, color: Colors.redAccent),
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

@override
  Widget build(BuildContext context) {
    final spots = points.map((point) => FlSpot(AppFormatters.doubleValue(point['x']), AppFormatters.doubleValue(point['value']))).toList();
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
            color: context.gymBorder,
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
                  AppFormatters.formatDate(points[index]['createdAt']),
                  style: TextStyle(color: context.gymMutedText, fontSize: 10),
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
                  '${AppFormatters.formatNumber(value)}$unit',
                  style: TextStyle(color: context.gymMutedText, fontSize: 10),
                );
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
            belowBarData: BarAreaData(
              show: true,
              color: context.gymFitnessAccent.withValues(alpha: 0.12),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.round();
                final date = index >= 0 && index < points.length ? AppFormatters.formatDate(points[index]['createdAt']) : '-';
                return LineTooltipItem(
                  '${AppFormatters.formatNumber(spot.y)} $unit\n$date',
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




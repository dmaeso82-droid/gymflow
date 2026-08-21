import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';
import '../utils/app_formatters.dart';

class PhysicalProgressSummary extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userEmail;
  final String title;
  final String emptyText;

  const PhysicalProgressSummary({
    super.key,
    required this.gymId,
    required this.userId,
    required this.userEmail,
    this.title = 'Progreso físico',
    this.emptyText = 'Todavía no hay medidas corporales registradas.',
  });

  CollectionReference<Map<String, dynamic>> get measurementsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('body_measurements');

  String signedValue(double value, String unit) {
    if (value > 0) return '+${AppFormatters.formatNumber(value)} $unit';
    if (value < 0) return '${AppFormatters.formatNumber(value)} $unit';
    return '0 $unit';
  }

  Color deltaColor(String metric, double value) {
    if (value == 0) return Colors.grey;
    final lowerIsBetter = metric == 'bodyWeight' || metric == 'waist';
    final positiveIsGood = !lowerIsBetter;
    final good = positiveIsGood ? value > 0 : value < 0;
    return good ? Colors.greenAccent : Colors.orangeAccent;
  }

  IconData deltaIcon(String metric, double value) {
    if (value == 0) return Icons.remove_rounded;
    final lowerIsBetter = metric == 'bodyWeight' || metric == 'waist';
    final positiveIsGood = !lowerIsBetter;
    final good = positiveIsGood ? value > 0 : value < 0;
    return good ? Icons.trending_up_rounded : Icons.trending_down_rounded;
  }

  bool matchesUser(Map<String, dynamic> data) {
    final normalizedEmail = userEmail.trim().toLowerCase();
    final storedEmail = (data['userEmail'] ?? '').toString().trim().toLowerCase();
    final storedUserId = (data['userId'] ?? '').toString().trim();
    return (userId.trim().isNotEmpty && storedUserId == userId.trim()) || (normalizedEmail.isNotEmpty && storedEmail == normalizedEmail);
  }

  PhysicalMetric metricFromMaps({
    required String key,
    required String label,
    required String unit,
    required IconData icon,
    required Map<String, dynamic> latest,
    required Map<String, dynamic> first,
  }) {
    final latestValue = AppFormatters.doubleValue(latest[key]);
    final firstValue = AppFormatters.doubleValue(first[key]);
    final hasDelta = latestValue > 0 && firstValue > 0;
    return PhysicalMetric(key: key, label: label, unit: unit, icon: icon, value: latestValue, delta: hasDelta ? latestValue - firstValue : 0, hasDelta: hasDelta);
  }

  String latestDateText(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day/$month/$year';
    }
    return 'Sin fecha';
  }

  @override
  Widget build(BuildContext context) {
    final normalizedEmail = userEmail.trim().toLowerCase();
    if (userId.trim().isEmpty && normalizedEmail.isEmpty) {
      return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PhysicalSectionHeader(title: title),
          const SizedBox(height: 10),
          Text('No hay identificador suficiente para cargar medidas.', style: TextStyle(color: context.gymMutedText)),
        ]),
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: measurementsRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppCard(child: Center(child: CircularProgressIndicator(color: context.gymPrimary)));
        }
        final measurements = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.data?.docs ?? []).where((doc) => matchesUser(doc.data())).toList();
        measurements.sort((a, b) => AppFormatters.timestampSortValue(b.data()['createdAt']).compareTo(AppFormatters.timestampSortValue(a.data()['createdAt'])));
        if (measurements.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(28)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PhysicalSectionHeader(title: title),
              const SizedBox(height: 10),
              Text(emptyText, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700)),
            ]),
          );
        }
        final latest = measurements.first.data();
        final first = measurements.last.data();
        final metrics = [
          metricFromMaps(key: 'bodyWeight', label: 'Peso', unit: 'kg', icon: Icons.monitor_weight_rounded, latest: latest, first: first),
          metricFromMaps(key: 'waist', label: 'Cintura', unit: 'cm', icon: Icons.straighten_rounded, latest: latest, first: first),
          metricFromMaps(key: 'chest', label: 'Pecho', unit: 'cm', icon: Icons.accessibility_new_rounded, latest: latest, first: first),
          metricFromMaps(key: 'arm', label: 'Brazo', unit: 'cm', icon: Icons.fitness_center_rounded, latest: latest, first: first),
          metricFromMaps(key: 'leg', label: 'Pierna', unit: 'cm', icon: Icons.directions_run_rounded, latest: latest, first: first),
        ].where((metric) => metric.value > 0).toList();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(30)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: PhysicalSectionHeader(title: title)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
                child: Text('${measurements.length} registros', style: TextStyle(color: context.gymPrimary, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ]),
            const SizedBox(height: 6),
            Text('Última medida: ${latestDateText(latest['createdAt'])}', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            if (metrics.isEmpty)
              Text('Hay registros, pero no contienen medidas visibles.', style: TextStyle(color: context.gymMutedText))
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 560 ? 2 : 3;
                  const spacing = 9.0;
                  final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: metrics.map((metric) {
                      return SizedBox(
                        width: width,
                        child: PhysicalMetricCard(
                          metric: metric,
                          formatNumber: AppFormatters.formatNumber,
                          signedValue: signedValue,
                          deltaColor: deltaColor(metric.key, metric.delta),
                          deltaIcon: deltaIcon(metric.key, metric.delta),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ]),
        );
      },
    );
  }
}

class PhysicalMetric {
  final String key;
  final String label;
  final String unit;
  final IconData icon;
  final double value;
  final double delta;
  final bool hasDelta;

  const PhysicalMetric({required this.key, required this.label, required this.unit, required this.icon, required this.value, required this.delta, required this.hasDelta});
}

class PhysicalSectionHeader extends StatelessWidget {
  final String title;

  const PhysicalSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(15)), child: Icon(Icons.monitor_weight_rounded, color: context.gymFitnessAccent, size: 20)),
      const SizedBox(width: 10),
      Expanded(child: Text(title, style: TextStyle(color: context.gymText, fontSize: 18, fontWeight: FontWeight.w900))),
    ]);
  }
}

class PhysicalMetricCard extends StatelessWidget {
  final PhysicalMetric metric;
  final String Function(num value) formatNumber;
  final String Function(double value, String unit) signedValue;
  final Color deltaColor;
  final IconData deltaIcon;

  const PhysicalMetricCard({super.key, required this.metric, required this.formatNumber, required this.signedValue, required this.deltaColor, required this.deltaIcon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: context.gymElevatedSurface.withValues(alpha: context.gymIsDark ? 0.46 : 0.58), borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(metric.icon, color: context.gymFitnessAccent, size: 16)),
          const SizedBox(width: 7),
          Expanded(child: Text(metric.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 9),
        Text('${formatNumber(metric.value)} ${metric.unit}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Row(children: [
          Icon(deltaIcon, color: deltaColor, size: 15),
          const SizedBox(width: 4),
          Expanded(child: Text(metric.hasDelta ? signedValue(metric.delta, metric.unit) : 'Sin cambio', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: deltaColor, fontSize: 11, fontWeight: FontWeight.w900))),
        ]),
      ]),
    );
  }
}

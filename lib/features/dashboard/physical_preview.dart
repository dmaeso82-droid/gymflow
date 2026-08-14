part of '../user_dashboard.dart';

class _PhysicalPreview extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;
  final CollectionReference<Map<String, dynamic>> measurementsRef;
  final CollectionReference<Map<String, dynamic>> progressPhotosRef;
  final int totalWorkouts;
  final int totalPoints;
  final String Function(dynamic value) formatDate;
  final double Function(dynamic value) doubleValue;
  final String Function(double value) formatCompactNumber;
  final int Function(dynamic value) timestampSortValue;

  const _PhysicalPreview({
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.measurementsRef,
    required this.progressPhotosRef,
    required this.totalWorkouts,
    required this.totalPoints,
    required this.formatDate,
    required this.doubleValue,
    required this.formatCompactNumber,
    required this.timestampSortValue,
  });

  Query<Map<String, dynamic>> photosQuery() {
    if (userId.trim().isNotEmpty) return progressPhotosRef.where('userId', isEqualTo: userId.trim());
    final normalizedEmail = userEmail.trim().toLowerCase();
    if (normalizedEmail.isNotEmpty) return progressPhotosRef.where('userEmail', isEqualTo: normalizedEmail);
    return progressPhotosRef.limit(1);
  }

  String deltaText(double value, String unit) {
    if (value == 0) return 'Sin cambio';
    final prefix = value > 0 ? '+' : '';
    return '$prefix${formatCompactNumber(value)} $unit';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: measurementsRef.where('userId', isEqualTo: userId).snapshots(),
      builder: (context, measurementsSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: photosQuery().snapshots(),
          builder: (context, photosSnapshot) {
            final measurements = [...(measurementsSnapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])];
            measurements.sort((a, b) => timestampSortValue(a.data()['createdAt']).compareTo(timestampSortValue(b.data()['createdAt'])));
            final firstMeasurement = measurements.isEmpty ? null : measurements.first.data();
            final latestMeasurement = measurements.isEmpty ? null : measurements.last.data();
            final firstWeight = firstMeasurement == null ? 0.0 : doubleValue(firstMeasurement['bodyWeight']);
            final latestWeight = latestMeasurement == null ? 0.0 : doubleValue(latestMeasurement['bodyWeight']);
            final firstWaist = firstMeasurement == null ? 0.0 : doubleValue(firstMeasurement['waist']);
            final latestWaist = latestMeasurement == null ? 0.0 : doubleValue(latestMeasurement['waist']);
            final weightDelta = firstWeight > 0 && latestWeight > 0 ? latestWeight - firstWeight : 0.0;
            final waistDelta = firstWaist > 0 && latestWaist > 0 ? latestWaist - firstWaist : 0.0;

            final photos = [...(photosSnapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])];
            photos.sort((a, b) => timestampSortValue(a.data()['createdAt']).compareTo(timestampSortValue(b.data()['createdAt'])));
            final beforePhoto = photos.isEmpty ? null : photos.first.data();
            final afterPhoto = photos.length < 2 ? null : photos.last.data();
            final hasBeforeAfter = beforePhoto != null && afterPhoto != null;
            final firstDate = photos.isNotEmpty ? formatDate(photos.first.data()['createdAt']) : 'Sin foto inicial';
            final lastDate = photos.length > 1 ? formatDate(photos.last.data()['createdAt']) : 'Sin foto actual';

            return AppCard(
              padding: const EdgeInsets.all(14),
              radius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _DashboardHeader(icon: Icons.compare_rounded, title: 'Mi transformación')),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProgressPhotosPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail),
                          ),
                        ),
                        icon: const Icon(Icons.photo_library_rounded, size: 18),
                        label: const Text('Fotos'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!hasBeforeAfter)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.gymBorder)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Icons.photo_camera_rounded, color: context.gymPrimary, size: 22),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('Crea tu antes y después', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                        ]),
                        const SizedBox(height: 6),
                        Text('Sube al menos dos fotos de progreso para activar la comparación visual.', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: _TransformationPhotoTile(label: 'ANTES', date: firstDate, imageUrl: beforePhoto['imageUrl']?.toString() ?? '')),
                        const SizedBox(width: 8),
                        Expanded(child: _TransformationPhotoTile(label: 'AHORA', date: lastDate, imageUrl: afterPhoto['imageUrl']?.toString() ?? '')),
                      ],
                    ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 8.0;
                      final width = (constraints.maxWidth - spacing) / 2;
                      return Wrap(spacing: spacing, runSpacing: spacing, children: [
                        SizedBox(width: width, child: _TransformationStat(icon: Icons.monitor_weight_rounded, value: deltaText(weightDelta, 'kg'), label: 'Peso vs inicio')),
                        SizedBox(width: width, child: _TransformationStat(icon: Icons.straighten_rounded, value: deltaText(waistDelta, 'cm'), label: 'Cintura vs inicio')),
                        SizedBox(width: width, child: _TransformationStat(icon: Icons.fitness_center_rounded, value: totalWorkouts.toString(), label: 'Entrenos totales')),
                        SizedBox(width: width, child: _TransformationStat(icon: Icons.emoji_events_rounded, value: '$totalPoints pts', label: 'Puntos ganados')),
                      ]);
                    },
                  ),
                  if (latestMeasurement != null) ...[
                    const SizedBox(height: 8),
                    Text('Última medida: ${formatDate(latestMeasurement['createdAt'])}', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TransformationPhotoTile extends StatelessWidget {
  final String label;
  final String date;
  final String imageUrl;
  const _TransformationPhotoTile({required this.label, required this.date, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.gymBorder)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isEmpty)
            ColoredBox(color: context.gymSubtleSurface, child: Icon(Icons.photo_rounded, color: context.gymMutedText.withValues(alpha: 0.55), size: 32))
          else
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(color: context.gymSubtleSurface, child: Icon(Icons.broken_image_rounded, color: context.gymMutedText.withValues(alpha: 0.55), size: 32)),
            ),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.56), borderRadius: BorderRadius.circular(999)),
              child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.50), borderRadius: BorderRadius.circular(12)),
              child: Text(date, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransformationStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _TransformationStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: context.gymSubtleSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.gymBorder)),
      child: Row(children: [
        Icon(icon, color: context.gymFitnessAccent, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _DashboardHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: context.gymFitnessAccent, size: 20),
        ),
        SizedBox(width: 10),
        Expanded(child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.gymText))),
      ],
    );
  }
}

class _RankingLite {
  final String userId;
  final String userEmail;
  final String userName;
  int series = 0;

  _RankingLite({required this.userId, required this.userEmail, required this.userName});
}

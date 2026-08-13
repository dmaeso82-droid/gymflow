import 'package:flutter/material.dart';
import '../services/stats_backfill_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';

class StatsBackfillPage extends StatefulWidget {
  final String gymId;

  const StatsBackfillPage({super.key, required this.gymId});

  @override
  State<StatsBackfillPage> createState() => _StatsBackfillPageState();
}

class _StatsBackfillPageState extends State<StatsBackfillPage> {
  bool running = false;
  StatsBackfillResult? result;
  String? error;

  StatsBackfillService get service => StatsBackfillService(gymId: widget.gymId);

  Future<void> runBackfill() async {
    if (running) return;
    setState(() {
      running = true;
      result = null;
      error = null;
    });
    try {
      final output = await service.rebuildStatsFromWorkoutLogs();
      if (!mounted) return;
      setState(() => result = output);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recalcular estadísticas')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: context.gymFitnessAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.sync, color: context.gymPrimary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Backfill de GymFlow', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: context.gymText)),
                            const SizedBox(height: 4),
                            Text(
                              'Reconstruye user_stats y ranking_stats usando los entrenamientos históricos.',
                              style: TextStyle(color: context.gymMutedText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Úsalo después de instalar la Fase 4 para que los usuarios antiguos aparezcan correctamente en estadísticas y rankings basados en datos precalculados.',
                    style: TextStyle(color: context.gymMutedText, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: running ? null : runBackfill,
                      icon: running
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(running ? 'Recalculando...' : 'Recalcular estadísticas ahora'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (result != null)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Icon(Icons.check_circle, color: context.gymFitnessAccent), const SizedBox(width: 8), Text('Recalculo completado', style: TextStyle(fontWeight: FontWeight.w900, color: context.gymText))]),
                    const SizedBox(height: 12),
                    _ResultRow(label: 'Logs procesados', value: result!.logsProcessed.toString()),
                    _ResultRow(label: 'Usuarios actualizados', value: result!.usersUpdated.toString()),
                    _ResultRow(label: 'Rankings actualizados', value: result!.rankingDocsUpdated.toString()),
                  ],
                ),
              ),
            if (error != null)
              AppCard(
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w800))),
          Text(value, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

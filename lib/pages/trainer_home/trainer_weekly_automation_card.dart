part of '../trainer_home_page.dart';

class _TrainerWeeklyAutomationCard extends StatefulWidget {
  final String gymId;
  final VoidCallback onOpenRoutines;
  final void Function(String clientId, String clientName) onOpenRoutineForClient;

  const _TrainerWeeklyAutomationCard({
    required this.gymId,
    required this.onOpenRoutines,
    required this.onOpenRoutineForClient,
  });

  @override
  State<_TrainerWeeklyAutomationCard> createState() => _TrainerWeeklyAutomationCardState();
}

class _TrainerWeeklyAutomationCardState extends State<_TrainerWeeklyAutomationCard> {
  late Future<_WeeklyAutomationData> future;
  bool preparing = false;

  TrainerRoutineService get service => TrainerRoutineService(gymId: widget.gymId);

  CollectionReference<Map<String, dynamic>> gymCollection(String name) {
    return FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection(name);
  }

  @override
  void initState() {
    super.initState();
    future = loadData();
  }

  String clientKey(QueryDocumentSnapshot<Map<String, dynamic>> client) {
    final authUid = client.data()['authUid']?.toString() ?? '';
    if (authUid.isNotEmpty) return authUid;
    return client.id;
  }

  Future<_WeeklyAutomationData> loadData() async {
    final clientsSnapshot = await gymCollection('clients').get();
    final routinesSnapshot = await gymCollection('routines').get();
    final weekKey = service.currentRoutineWeekKey();
    final activeClients = clientsSnapshot.docs.where((doc) => doc.data()['active'] != false).toList();
    final activeRoutines = routinesSnapshot.docs.where((doc) {
      final status = (doc.data()['status'] ?? 'active').toString();
      return status != 'archived';
    }).toList();

    final routinesByClient = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final routine in activeRoutines) {
      final data = routine.data();
      final clientId = data['clientId']?.toString() ?? '';
      final clientEmail = (data['clientEmail'] ?? '').toString().trim().toLowerCase();
      if (clientId.isNotEmpty) routinesByClient.putIfAbsent(clientId, () => []).add(routine);
      if (clientEmail.isNotEmpty) routinesByClient.putIfAbsent(clientEmail, () => []).add(routine);
    }

    final needsWeek = <_WeeklyClientEntry>[];
    final noRoutine = <_WeeklyClientEntry>[];
    var alreadyPrepared = 0;

    for (final client in activeClients) {
      final data = client.data();
      final name = data['name']?.toString() ?? 'Cliente';
      final email = (data['email'] ?? '').toString().trim().toLowerCase();
      final keys = <String>{client.id, clientKey(client), if (email.isNotEmpty) email};
      final routines = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final key in keys) {
        routines.addAll(routinesByClient[key] ?? []);
      }
      final uniqueRoutines = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{for (final routine in routines) routine.id: routine}.values.toList();
      if (uniqueRoutines.isEmpty) {
        noRoutine.add(_WeeklyClientEntry(clientId: client.id, clientName: name, clientData: data, reason: 'Sin rutina activa'));
        continue;
      }
      final hasCurrentWeek = uniqueRoutines.any((routine) {
        final data = routine.data();
        final routineWeekKey = (data['routineWeekKey'] ?? data['weekKey'] ?? '').toString();
        return routineWeekKey == weekKey;
      });
      if (hasCurrentWeek) {
        alreadyPrepared++;
      } else {
        needsWeek.add(_WeeklyClientEntry(clientId: client.id, clientName: name, clientData: data, reason: 'Semana actual pendiente'));
      }
    }

    return _WeeklyAutomationData(
      weekKey: weekKey,
      needsWeek: needsWeek,
      noRoutine: noRoutine,
      alreadyPrepared: alreadyPrepared,
      totalActiveClients: activeClients.length,
    );
  }

  Future<void> refresh() async {
    setState(() => future = loadData());
  }

  Future<void> preparePendingWeeks(_WeeklyAutomationData data) async {
    if (data.needsWeek.isEmpty || preparing) return;
    setState(() => preparing = true);
    var prepared = 0;
    final errors = <String>[];
    for (final entry in data.needsWeek) {
      try {
        final result = await service.prepareCurrentWeekForClient(clientId: entry.clientId, clientData: entry.clientData);
        if (!result.toLowerCase().contains('no hay rutinas activas')) prepared++;
      } catch (_) {
        errors.add(entry.clientName);
      }
    }
    if (!mounted) return;
    setState(() {
      preparing = false;
      future = loadData();
    });
    final message = errors.isEmpty
        ? 'Semanas preparadas para $prepared cliente${prepared == 1 ? '' : 's'}.'
        : 'Preparadas: $prepared. Con error: ${errors.take(3).join(', ')}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WeeklyAutomationData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: context.gymPrimary)),
                const SizedBox(width: 12),
                Expanded(child: Text('Analizando semanas de entrenamiento...', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w800))),
              ],
            ),
          );
        }

        final data = snapshot.data;
        if (data == null || data.totalActiveClients == 0) return const SizedBox.shrink();

        final pending = data.needsWeek.length;
        final noRoutine = data.noRoutine.length;
        final allReady = pending == 0 && noRoutine == 0;
        final accent = allReady ? Colors.greenAccent : Colors.orangeAccent;

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(17)),
                    child: Icon(allReady ? Icons.verified_rounded : Icons.auto_mode_rounded, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Automatización semanal', style: TextStyle(color: context.gymText, fontSize: 17, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('Semana ${data.weekKey}', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  _AutomationChip(icon: Icons.check_circle_rounded, label: '${data.alreadyPrepared} listos', color: Colors.greenAccent),
                  const SizedBox(width: 6),
                  _AutomationChip(icon: Icons.assignment_late_rounded, label: '$noRoutine sin rutina', color: noRoutine > 0 ? Colors.redAccent : context.gymMutedText),
                  IconButton(tooltip: 'Actualizar', onPressed: refresh, icon: const Icon(Icons.refresh_rounded)),
                ],
              ),
              if (pending > 0) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: preparing ? null : () => preparePendingWeeks(data),
                    icon: preparing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_mode_rounded),
                    label: Text(preparing ? 'PREPARANDO...' : 'PREPARAR $pending PENDIENTE${pending == 1 ? '' : 'S'}'),
                  ),
                ),
              ],
              if (noRoutine > 0) ...[
                const SizedBox(height: 12),
                Text('Clientes sin rutina base', style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                ...data.noRoutine.take(2).map((entry) => _WeeklyAutomationClientRow(entry: entry, color: Colors.redAccent, onTap: () => widget.onOpenRoutineForClient(entry.clientId, entry.clientName))),
                if (data.noRoutine.length > 2) TextButton.icon(onPressed: widget.onOpenRoutines, icon: const Icon(Icons.list_alt_rounded), label: Text('Ver ${data.noRoutine.length - 2} más')),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AutomationChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _AutomationChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _WeeklyAutomationData {
  final String weekKey;
  final List<_WeeklyClientEntry> needsWeek;
  final List<_WeeklyClientEntry> noRoutine;
  final int alreadyPrepared;
  final int totalActiveClients;

  const _WeeklyAutomationData({required this.weekKey, required this.needsWeek, required this.noRoutine, required this.alreadyPrepared, required this.totalActiveClients});
}

class _WeeklyClientEntry {
  final String clientId;
  final String clientName;
  final Map<String, dynamic> clientData;
  final String reason;

  const _WeeklyClientEntry({required this.clientId, required this.clientName, required this.clientData, required this.reason});
}

class _WeeklyAutomationClientRow extends StatelessWidget {
  final _WeeklyClientEntry entry;
  final Color color;
  final VoidCallback onTap;

  const _WeeklyAutomationClientRow({required this.entry, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: context.gymElevatedSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.54), borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.person_rounded, color: color, size: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entry.clientName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(entry.reason, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/duel_service.dart';

class DuelCreationResult {
  final DuelUserOption challenger;
  final DuelUserOption opponent;
  final String metric;
  final double target;
  final int points;

  const DuelCreationResult({
    required this.challenger,
    required this.opponent,
    required this.metric,
    required this.target,
    required this.points,
  });
}

Future<DuelCreationResult?> showDuelCreationDialog({
  required BuildContext context,
  required DuelService service,
  required String currentUserId,
  required String currentUserName,
  required String currentUserEmail,
  bool trainerMode = false,
}) async {
  final rawUsers = await service.loadClientOptions();
  if (!context.mounted) return null;

  final users = <DuelUserOption>[];
  final seenKeys = <String>{};
  for (final user in rawUsers) {
    final key = user.email.trim().isNotEmpty ? user.email.trim().toLowerCase() : user.id.trim();
    if (key.isEmpty || seenKeys.contains(key)) continue;
    seenKeys.add(key);
    users.add(user);
  }

  if (users.length < 2) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Necesitas al menos dos clientes para crear un duelo.')),
    );
    return null;
  }

  final normalizedCurrentEmail = currentUserEmail.trim().toLowerCase();
  DuelUserOption? currentUserOption;
  for (final user in users) {
    final sameId = currentUserId.trim().isNotEmpty && user.id == currentUserId.trim();
    final sameEmail = normalizedCurrentEmail.isNotEmpty && user.email == normalizedCurrentEmail;
    if (sameId || sameEmail) {
      currentUserOption = user;
      break;
    }
  }

  if (!trainerMode && currentUserOption == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se ha encontrado tu ficha de cliente para crear el duelo.')),
    );
    return null;
  }

  var challenger = trainerMode ? users.first : currentUserOption!;
  var opponentOptions = users
      .where((user) => user.id != challenger.id && user.email != challenger.email)
      .toList();
  if (opponentOptions.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hay otros clientes disponibles para retar.')),
    );
    return null;
  }

  var opponent = opponentOptions.first;
  var metric = 'workout_count';
  final targetController = TextEditingController(text: '10');
  final pointsController = TextEditingController(text: '100');

  try {
    return await showDialog<DuelCreationResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            opponentOptions = users
                .where((user) => user.id != challenger.id && user.email != challenger.email)
                .toList();
            if (opponentOptions.isNotEmpty &&
                !opponentOptions.any((user) => user.id == opponent.id && user.email == opponent.email)) {
              opponent = opponentOptions.first;
            }

            return AlertDialog(
              backgroundColor: context.gymSurface,
              title: Text(trainerMode ? 'Crear reto 1 vs 1' : 'Retar a un cliente', style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (trainerMode) ...[
                      DropdownButtonFormField<String>(
                        initialValue: challenger.id,
                        dropdownColor: context.gymSurface,
                        decoration: InputDecoration(labelText: 'Retador', filled: true, fillColor: context.gymSubtleSurface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                        items: users.map((user) => DropdownMenuItem(value: user.id, child: Text(user.name, style: TextStyle(color: context.gymText)))).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            challenger = users.firstWhere((user) => user.id == value);
                            final nextOptions = users
                                .where((user) => user.id != challenger.id && user.email != challenger.email)
                                .toList();
                            if (nextOptions.isNotEmpty) opponent = nextOptions.first;
                          });
                        },
                      ),
                      SizedBox(height: 12),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.gymSubtleSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.gymBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Retador', style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w800)),
                            SizedBox(height: 4),
                            Text(challenger.name, style: TextStyle(fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: opponent.id,
                      dropdownColor: context.gymSurface,
                      decoration: InputDecoration(labelText: 'Oponente', filled: true, fillColor: context.gymSubtleSurface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                      items: opponentOptions.map((user) => DropdownMenuItem(value: user.id, child: Text(user.name, style: TextStyle(color: context.gymText)))).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => opponent = opponentOptions.firstWhere((user) => user.id == value));
                      },
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: metric,
                      dropdownColor: context.gymSurface,
                      decoration: InputDecoration(labelText: 'Tipo de duelo', filled: true, fillColor: context.gymSubtleSurface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                      items: [
                        DropdownMenuItem(value: 'workout_count', child: Text('Entrenamientos')),
                        DropdownMenuItem(value: 'volume_total', child: Text('Volumen movido')),
                        DropdownMenuItem(value: 'series_count', child: Text('Series completadas')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          metric = value;
                          targetController.text = value == 'volume_total' ? '50000' : '10';
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: targetController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Objetivo (${service.metricUnit(metric)})',
                        filled: true,
                        fillColor: context.gymSubtleSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: pointsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Puntos para el ganador', filled: true, fillColor: context.gymSubtleSurface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancelar')),
                FilledButton.icon(
                  onPressed: () {
                    final target = double.tryParse(targetController.text.trim().replaceAll(',', '.')) ?? 0;
                    final points = int.tryParse(pointsController.text.trim()) ?? 100;
                    final sameUser = challenger.id == opponent.id || challenger.email == opponent.email;
                    if (target <= 0 || sameUser) return;
                    Navigator.pop(
                      dialogContext,
                      DuelCreationResult(
                        challenger: challenger,
                        opponent: opponent,
                        metric: metric,
                        target: target,
                        points: points,
                      ),
                    );
                  },
                  icon: Icon(Icons.sports_mma),
                  label: Text('Crear duelo'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    targetController.dispose();
    pointsController.dispose();
  }
}




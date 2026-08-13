import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/workout_utils.dart';

class WorkoutLogDialogResult {
  final Map<String, dynamic> exercise;
  final double weight;
  final int reps;
  final int setNumber;
  final int plannedSetCount;

  const WorkoutLogDialogResult({
    required this.exercise,
    required this.weight,
    required this.reps,
    required this.setNumber,
    required this.plannedSetCount,
  });
}

const List<int> defaultQuickReps = <int>[6, 8, 10, 12, 15];

List<double> compactWeightOptions(double? base) {
  if (base == null || base <= 0) {
	return const [5, 10, 12.5, 20, 25, 30, 35, 40, 45, 50, 60];
  }
  if (base >= 45) {
    return const [45, 50, 55, 60, 70, 80, 90, 100];
  }
  if (base >= 20) {
    return const [20, 22.5, 25, 27.5, 30, 32.5, 35, 40, 45];
  }
  return const [2.5, 5, 7.5, 10, 12.5, 15, 17.5, 20, 25];
}

Future<WorkoutLogDialogResult?> showWorkoutLogDialog({
  required BuildContext context,
  required List<dynamic> exercises,
  required String exerciseId,
}) async {
  final exercise = exercises
      .map((item) => Map<String, dynamic>.from(item as Map))
      .firstWhere((item) => item['id'] == exerciseId);

  final plannedSetCount = workoutTotalSets(exercise);
  final currentCompletedSets = workoutCompletedSets(exercise);

  if (currentCompletedSets >= plannedSetCount) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Este ejercicio ya tiene todas las series registradas.')),
    );
    return null;
  }

  final nextSetNumber = currentCompletedSets + 1;
  final weightText = (exercise['weight'] ?? '').toString();
  final repsText = (exercise['reps'] ?? '').toString();
  final suggestedWeightRaw = RegExp(r'\d+(?:[\.,]\d+)?').firstMatch(weightText)?.group(0) ?? '';
  final suggestedWeight = suggestedWeightRaw.replaceAll('.', ',');
  final suggestedWeightValue = workoutDecimalValue(suggestedWeight);
  final suggestedReps = RegExp(r'\d+').firstMatch(repsText)?.group(0) ?? '';
  final weightOptions = compactWeightOptions(suggestedWeightValue);
  final weightController = TextEditingController(text: suggestedWeight);
  final repsController = TextEditingController(text: suggestedReps);
  bool showManualWeight = suggestedWeight.isEmpty;
  bool showManualReps = suggestedReps.isEmpty;

  try {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isCompact = MediaQuery.of(context).size.width < 600;

            Widget sectionLabel(String text) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: context.gymMutedText,
                    fontSize: 13,
                  ),
                ),
              );
            }

            Widget compactChip({
              required String text,
              required bool selected,
              required VoidCallback onTap,
              double? width,
            }) {
              return SizedBox(
                width: width,
                height: 38,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: selected ? context.gymFitnessAccent.withValues(alpha: 0.18) : context.gymInsetSurface,
                    side: BorderSide(color: selected ? context.gymFitnessAccent : context.gymBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onTap,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected) ...[
                        Icon(Icons.check, size: 16, color: context.gymFitnessAccent),
                        SizedBox(width: 3),
                      ],
                      Flexible(
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? context.gymFitnessAccent : context.gymMutedText,
                            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                            fontSize: isCompact ? 12 : 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: context.gymSurface,
              insetPadding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 40, vertical: isCompact ? 14 : 24),
              titlePadding: EdgeInsets.fromLTRB(isCompact ? 14 : 20, isCompact ? 14 : 20, isCompact ? 14 : 20, 6),
              contentPadding: EdgeInsets.fromLTRB(isCompact ? 14 : 20, 4, isCompact ? 14 : 20, 0),
              actionsPadding: EdgeInsets.fromLTRB(isCompact ? 12 : 16, 4, isCompact ? 12 : 16, isCompact ? 12 : 16),
              title: Text(
                'Registrar ${exercise['name'] ?? 'ejercicio'} ($nextSetNumber/$plannedSetCount)',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: isCompact ? 20 : 22, fontWeight: FontWeight.w900),
              ),
              content: LayoutBuilder(
                builder: (context, constraints) {
                  final chipWidth = ((constraints.maxWidth - 18) / 4).clamp(62.0, 92.0).toDouble();
                  final selectedWeight = weightController.text.trim();
                  final selectedReps = repsController.text.trim();

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        sectionLabel('Peso'),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ...weightOptions.map((weight) {
                              final text = workoutFormatWeight(weight);
                              final selected = selectedWeight == text;
                              return compactChip(
                                text: '$text kg',
                                selected: selected,
                                width: chipWidth,
                                onTap: () => setDialogState(() {
                                  weightController.text = text;
                                  showManualWeight = false;
                                }),
                              );
                            }),
                            compactChip(
                              text: 'Otro',
                              selected: showManualWeight,
                              width: chipWidth,
                              onTap: () => setDialogState(() => showManualWeight = !showManualWeight),
                            ),
                          ],
                        ),
                        if (showManualWeight) ...[
                          SizedBox(height: 8),
                          TextField(
                            controller: weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Peso personalizado (kg)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ],
                        SizedBox(height: 12),
                        sectionLabel('Reps'),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ...defaultQuickReps.map((reps) {
                              final text = reps.toString();
                              final selected = selectedReps == text;
                              return compactChip(
                                text: text,
                                selected: selected,
                                width: chipWidth,
                                onTap: () => setDialogState(() {
                                  repsController.text = text;
                                  showManualReps = false;
                                }),
                              );
                            }),
                            compactChip(
                              text: 'Otra',
                              selected: showManualReps,
                              width: chipWidth,
                              onTap: () => setDialogState(() => showManualReps = !showManualReps),
                            ),
                          ],
                        ),
                        if (showManualReps) ...[
                          SizedBox(height: 8),
                          TextField(
                            controller: repsController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Repeticiones personalizadas',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ],
                        SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: context.gymInsetSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.gymBorder),
                          ),
                          child: Text(
                            weightController.text.trim().isEmpty && repsController.text.trim().isEmpty
                                ? 'Selecciona peso y repeticiones'
                                : '${weightController.text.trim().isEmpty ? '?' : weightController.text.trim()} kg · ${repsController.text.trim().isEmpty ? '?' : repsController.text.trim()} reps',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: context.gymFitnessAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text('Cancelar'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () {
                          final weight = workoutDecimalValue(weightController.text);
                          final reps = int.tryParse(repsController.text.trim());
                          if (weight == null || reps == null || weight < 0 || reps <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Introduce peso y repeticiones válidas.')),
                            );
                            return;
                          }
                          Navigator.pop(dialogContext, {'weight': weight, 'reps': reps});
                        },
                        icon: Icon(Icons.save, size: 18),
                        label: Text('Guardar $nextSetNumber/$plannedSetCount'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return null;

    return WorkoutLogDialogResult(
      exercise: exercise,
      weight: result['weight'] as double,
      reps: result['reps'] as int,
      setNumber: nextSetNumber,
      plannedSetCount: plannedSetCount,
    );
  } finally {
    weightController.dispose();
    repsController.dispose();
  }
}




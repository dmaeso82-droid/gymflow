
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/day_utils.dart';
import '../theme/app_theme.dart';

import '../widgets/app_card.dart';
import '../widgets/info_chip.dart';

class TrainerCalendarPage extends StatefulWidget {
  final String gymId;

  const TrainerCalendarPage({super.key, required this.gymId});

  @override
  State<TrainerCalendarPage> createState() => _TrainerCalendarPageState();
}

class _TrainerCalendarPageState extends State<TrainerCalendarPage> {
  String? selectedClientId;

  CollectionReference<Map<String, dynamic>> get clientsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('clients');

  CollectionReference<Map<String, dynamic>> get routinesRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('routines');


  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    final pagePadding = isCompact ? 12.0 : 16.0;
    final sectionGap = isCompact ? 10.0 : 16.0;

    return Scaffold(
      appBar: AppBar(title: Text('Calendario semanal')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: clientsRef.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, clientSnapshot) {
            final clients = clientSnapshot.data?.docs ?? [];
            if (selectedClientId == null && clients.isNotEmpty) selectedClientId = clients.first.id;

            return ListView(
              padding: EdgeInsets.all(pagePadding),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_search, color: context.gymPrimary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Cliente',
                            style: TextStyle(fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      SizedBox(height: isCompact ? 8 : 12),
                      if (clients.isEmpty)
                        Text('Primero crea un cliente.', style: TextStyle(color: context.gymMutedText))
                      else
                        DropdownButtonFormField<String>(
                          initialValue: selectedClientId,
                          isDense: isCompact,
                          dropdownColor: context.gymSurface,
                          decoration: InputDecoration(
                            labelText: 'Cliente seleccionado',
                            border: const OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: isCompact ? 10 : 14,
                            ),
                          ),
                          items: clients.map((doc) {
                            final data = doc.data();
                            final name = data['name'] ?? 'Sin nombre';
                            final email = data['email'] ?? 'Sin email';
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Text(
                                isCompact ? name.toString() : '$name · $email',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => selectedClientId = value),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: selectedClientId == null ? null : routinesRef.where('clientId', isEqualTo: selectedClientId).snapshots(),
                  builder: (context, routineSnapshot) {
                    final routines = (routineSnapshot.data?.docs ?? []).toList();

                    return Column(
                      children: DayUtils.weekDays.map((day) {
                        final dayRoutines = routines.where((doc) => (doc.data()['day'] ?? '').toString() == day).toList();
                        final totalExercises = dayRoutines.fold<int>(0, (total, doc) {
                          final exercises = List<dynamic>.from(doc.data()['exercises'] ?? []);
                          return total + exercises.length;
                        });

                        return AppCard(
                          margin: EdgeInsets.only(bottom: isCompact ? 8 : 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      day,
                                      style: TextStyle(fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  if (dayRoutines.isNotEmpty)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isCompact ? 8 : 10,
                                        vertical: isCompact ? 4 : 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.gymFitnessAccent.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '${dayRoutines.length} rutina${dayRoutines.length == 1 ? '' : 's'}',
                                        style: TextStyle(fontSize: isCompact ? 11 : 12, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: isCompact ? 6 : 10),
                              if (dayRoutines.isEmpty)
                                Text(
                                  'Sin rutina asignada.',
                                  style: TextStyle(color: context.gymMutedText, fontSize: isCompact ? 13 : 14),
                                )
                              else
                                ...dayRoutines.map((doc) {
                                  final data = doc.data();
                                  final exercises = List<dynamic>.from(data['exercises'] ?? []);
                                  final title = data['title']?.toString() ?? 'Rutina';

                                  if (isCompact) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: context.gymSubtleSurface,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: context.gymBorder),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.fitness_center, size: 17, color: context.gymPrimary),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontWeight: FontWeight.w800),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            '${exercises.length} ej.',
                                            style: TextStyle(color: context.gymMutedText, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        InfoChip(text: title),
                                        InfoChip(text: '${exercises.length} ejercicios'),
                                      ],
                                    ),
                                  );
                                }),
                              if (isCompact && totalExercises > 0) ...[
                                SizedBox(height: 2),
                                Text(
                                  '$totalExercises ejercicios en total',
                                  style: TextStyle(color: context.gymMutedText.withValues(alpha: 0.70), fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}




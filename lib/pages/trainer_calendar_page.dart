
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';

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

  static const weekDays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    final pagePadding = isCompact ? 12.0 : 16.0;
    final sectionGap = isCompact ? 10.0 : 16.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario semanal')),
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
                          const Icon(Icons.person_search, color: Colors.greenAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Cliente',
                            style: TextStyle(fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      SizedBox(height: isCompact ? 8 : 12),
                      if (clients.isEmpty)
                        const Text('Primero crea un cliente.', style: TextStyle(color: Colors.white70))
                      else
                        DropdownButtonFormField<String>(
                          value: selectedClientId,
                          isDense: isCompact,
                          dropdownColor: const Color(0xFF0F172A),
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
                  stream: routinesRef.snapshots(),
                  builder: (context, routineSnapshot) {
                    final routines = (routineSnapshot.data?.docs ?? [])
                        .where((doc) => doc.data()['clientId'] == selectedClientId)
                        .toList();

                    return Column(
                      children: weekDays.map((day) {
                        final dayRoutines = routines.where((doc) => (doc.data()['day'] ?? '').toString() == day).toList();
                        final totalExercises = dayRoutines.fold<int>(0, (sum, doc) {
                          final exercises = List<dynamic>.from(doc.data()['exercises'] ?? []);
                          return sum + exercises.length;
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
                                        color: Colors.greenAccent.withOpacity(0.14),
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
                                  style: TextStyle(color: Colors.white70, fontSize: isCompact ? 13 : 14),
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
                                        color: const Color(0xFF020617),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.fitness_center, size: 17, color: Colors.greenAccent),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${exercises.length} ej.',
                                            style: const TextStyle(color: Colors.white60, fontSize: 12),
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
                                const SizedBox(height: 2),
                                Text(
                                  '$totalExercises ejercicios en total',
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
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


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
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario semanal')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: clientsRef.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, clientSnapshot) {
            final clients = clientSnapshot.data?.docs ?? [];
            if (selectedClientId == null && clients.isNotEmpty) selectedClientId = clients.first.id;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(icon: Icons.person_search, title: 'Cliente'),
                      const SizedBox(height: 12),
                      if (clients.isEmpty)
                        const Text('Primero crea un cliente.', style: TextStyle(color: Colors.white70))
                      else
                        DropdownButtonFormField<String>(
                          value: selectedClientId,
                          dropdownColor: const Color(0xFF0F172A),
                          decoration: const InputDecoration(labelText: 'Cliente seleccionado', border: OutlineInputBorder()),
                          items: clients.map((doc) {
                            final data = doc.data();
                            return DropdownMenuItem(value: doc.id, child: Text('${data['name'] ?? 'Sin nombre'} · ${data['email'] ?? 'Sin email'}'));
                          }).toList(),
                          onChanged: (value) => setState(() => selectedClientId = value),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: routinesRef.snapshots(),
                  builder: (context, routineSnapshot) {
                    final routines = (routineSnapshot.data?.docs ?? [])
                        .where((doc) => doc.data()['clientId'] == selectedClientId)
                        .toList();

                    return Column(
                      children: weekDays.map((day) {
                        final dayRoutines = routines.where((doc) => (doc.data()['day'] ?? '').toString() == day).toList();
                        return AppCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(day, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 10),
                              if (dayRoutines.isEmpty)
                                const Text('Sin rutina asignada.', style: TextStyle(color: Colors.white70))
                              else
                                ...dayRoutines.map((doc) {
                                  final data = doc.data();
                                  final exercises = List<dynamic>.from(data['exercises'] ?? []);
                                  return Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      InfoChip(text: data['title']?.toString() ?? 'Rutina'),
                                      InfoChip(text: '${exercises.length} ejercicios'),
                                    ],
                                  );
                                }),
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

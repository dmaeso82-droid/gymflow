
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';

class UserCalendarPage extends StatelessWidget {
  final String gymId;
  final String userEmail;

  const UserCalendarPage({super.key, required this.gymId, required this.userEmail});

  CollectionReference<Map<String, dynamic>> get routinesRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('routines');

  static const weekDays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario semanal')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: routinesRef.where('clientEmail', isEqualTo: userEmail.toLowerCase()).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final routines = snapshot.data?.docs ?? [];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const AppCard(
                  child: SectionTitle(icon: Icons.calendar_month, title: 'Mi semana'),
                ),
                const SizedBox(height: 16),
                ...weekDays.map((day) {
                  final dayRoutines = routines.where((doc) => (doc.data()['day'] ?? '').toString() == day).toList();

                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(day, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        if (dayRoutines.isEmpty)
                          const Text('Descanso o sin rutina asignada.', style: TextStyle(color: Colors.white70))
                        else
                          ...dayRoutines.map((doc) {
                            final data = doc.data();
                            final exercises = List<dynamic>.from(data['exercises'] ?? []);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  InfoChip(text: data['title']?.toString() ?? 'Rutina'),
                                  InfoChip(text: '${exercises.length} ejercicios'),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

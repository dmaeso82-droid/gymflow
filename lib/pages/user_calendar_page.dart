
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/day_utils.dart';
import '../theme/app_theme.dart';

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


  bool isActiveRoutine(Map<String, dynamic> data) {
    return (data['status'] ?? 'active').toString() != 'archived';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Calendario semanal')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: routinesRef.where('clientEmail', isEqualTo: userEmail.toLowerCase()).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            final routines = (snapshot.data?.docs ?? [])
                .where((doc) => isActiveRoutine(doc.data()))
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  child: SectionTitle(icon: Icons.calendar_month, title: 'Mi semana'),
                ),
                SizedBox(height: 16),
                ...DayUtils.weekDays.map((day) {
                  final dayRoutines = routines.where((doc) => (doc.data()['day'] ?? '').toString() == day).toList();

                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(day, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        SizedBox(height: 10),
                        if (dayRoutines.isEmpty)
                          Text('Descanso o sin rutina activa asignada.', style: TextStyle(color: context.gymMutedText))
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




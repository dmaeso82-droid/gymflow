import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../features/client_goals.dart';
import '../widgets/app_card.dart';
import '../widgets/section_title.dart';

class TrainerGoalsPage extends StatefulWidget {
  final String gymId;

  const TrainerGoalsPage({super.key, required this.gymId});

  @override
  State<TrainerGoalsPage> createState() => _TrainerGoalsPageState();
}

class _TrainerGoalsPageState extends State<TrainerGoalsPage> {
  String? selectedClientId;

  CollectionReference<Map<String, dynamic>> get clientsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('clients');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Objetivos')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: clientsRef.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            final clients = snapshot.data?.docs ?? [];
            if (selectedClientId == null && clients.isNotEmpty) selectedClientId = clients.first.id;

            QueryDocumentSnapshot<Map<String, dynamic>>? selected;
            for (final doc in clients) {
              if (doc.id == selectedClientId) selected = doc;
            }

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
                if (selected != null)
                  ClientGoalsPanel(
                    gymId: widget.gymId,
                    clientName: selected.data()['name']?.toString() ?? 'Cliente',
                    clientEmail: (selected.data()['email'] ?? '').toString().toLowerCase(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

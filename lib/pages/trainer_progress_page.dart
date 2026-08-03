
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../features/client_progress.dart';
import '../widgets/app_card.dart';
import '../widgets/section_title.dart';

class TrainerProgressPage extends StatefulWidget {
  final String gymId;

  const TrainerProgressPage({super.key, required this.gymId});

  @override
  State<TrainerProgressPage> createState() => _TrainerProgressPageState();
}

class _TrainerProgressPageState extends State<TrainerProgressPage> {
  String? selectedClientId;

  CollectionReference<Map<String, dynamic>> get clientsRef => FirebaseFirestore.instance
      .collection('gyms')
      .doc(widget.gymId)
      .collection('clients');

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    final pagePadding = isCompact ? 12.0 : 16.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Progreso')),
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
                SizedBox(height: isCompact ? 10 : 16),
                if (selected != null)
                  ClientProgress(
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

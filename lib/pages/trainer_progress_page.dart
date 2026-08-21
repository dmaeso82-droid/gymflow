import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../features/client_progress.dart';
import '../widgets/physical_progress_summary.dart';
import '../widgets/profile_avatar.dart';
class TrainerProgressPage extends StatefulWidget {
  final String gymId;
  const TrainerProgressPage({super.key, required this.gymId});
  @override
  State<TrainerProgressPage> createState() => _TrainerProgressPageState();
}
class _TrainerProgressPageState extends State<TrainerProgressPage> {
  String? selectedClientId;
  CollectionReference<Map<String, dynamic>> get clientsRef => FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('clients');
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
            if (clients.isEmpty) {
              return ListView(padding: EdgeInsets.all(pagePadding), children: const [
                _TrainerEmptyState(icon: Icons.people_outline_rounded, title: 'Primero crea un cliente', subtitle: 'Cuando tengas clientes, podrás revisar su progreso físico aquí.'),
              ]);
            }
            final selectedData = selected?.data() ?? {};
            final selectedName = selectedData['name']?.toString() ?? 'Cliente';
            final selectedEmail = (selectedData['email'] ?? '').toString().toLowerCase();
            return ListView(
              padding: EdgeInsets.fromLTRB(pagePadding, pagePadding, pagePadding, 92),
              children: [
                _ProgressHero(name: selectedName, email: selectedEmail, clientsCount: clients.length),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedClientId,
                  isDense: isCompact,
                  dropdownColor: context.gymSurface,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_search_rounded),
                    labelText: 'Cliente seleccionado',
                    filled: true,
                    fillColor: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.44 : 0.68),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  ),
                  items: clients.map((doc) {
                    final data = doc.data();
                    final name = data['name'] ?? 'Sin nombre';
                    final email = data['email'] ?? 'Sin email';
                    return DropdownMenuItem(value: doc.id, child: Text(isCompact ? name.toString() : '$name · $email', overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (value) => setState(() => selectedClientId = value),
                ),
                const SizedBox(height: 12),
                if (selected != null) ...[
                  PhysicalProgressSummary(
                    gymId: widget.gymId,
                    userId: selected.id,
                    userEmail: selectedEmail,
                    title: 'Resumen físico del cliente',
                    emptyText: 'Este cliente todavía no tiene medidas corporales registradas.',
                  ),
                  SizedBox(height: isCompact ? 10 : 16),
                  ClientProgress(
                    gymId: widget.gymId,
                    clientName: selectedName,
                    clientEmail: selectedEmail,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
class _ProgressHero extends StatelessWidget {
  final String name;
  final String email;
  final int clientsCount;
  const _ProgressHero({required this.name, required this.email, required this.clientsCount});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(28)),
      child: Row(children: [
        ProfileAvatar(name: name, size: 48),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Progreso', style: TextStyle(color: context.gymText, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
          const SizedBox(height: 4),
          Text('$name · $clientsCount clientes', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12.5, fontWeight: FontWeight.w800)),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ])),
      ]),
    );
  }
}
class _TrainerEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _TrainerEmptyState({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(26)),
      child: Column(children: [
        Icon(icon, color: context.gymPrimary, size: 34),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: TextStyle(color: context.gymText, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

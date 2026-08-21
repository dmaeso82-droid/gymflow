import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../constants.dart';
import '../services/invitation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/section_title.dart';

class InvitationsPage extends StatefulWidget {
  final String gymId;
  const InvitationsPage({super.key, required this.gymId});

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  final trainerNameController = TextEditingController();
  final trainerEmailController = TextEditingController();
  final clientNameController = TextEditingController();
  final clientEmailController = TextEditingController();
  bool loading = false;
  String selectedTrainerRole = trainerRoleTrainer;
  String selectedStatusFilter = 'all';

  InvitationService get service => InvitationService(gymId: widget.gymId);

  @override
  void dispose() {
    trainerNameController.dispose();
    trainerEmailController.dispose();
    clientNameController.dispose();
    clientEmailController.dispose();
    super.dispose();
  }

  void showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<Map<String, String>> currentActor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'uid': '', 'name': 'Admin', 'email': ''};
    var name = user.displayName ?? '';
    final email = user.email ?? '';
    if (name.trim().isEmpty) name = email.isEmpty ? 'Admin' : email;
    return {'uid': user.uid, 'name': name, 'email': email};
  }

  Future<void> createInvite({required bool trainer}) async {
    final nameController = trainer ? trainerNameController : clientNameController;
    final emailController = trainer ? trainerEmailController : clientEmailController;
    final name = nameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    if (name.isEmpty || email.isEmpty) {
      showSnack('Introduce nombre y email.');
      return;
    }
    setState(() => loading = true);
    try {
      final actor = await currentActor();
      final link = await service.createInvite(
        name: name,
        email: email,
        role: trainer ? roleTrainer : roleUser,
        trainerRole: trainer ? selectedTrainerRole : trainerRoleTrainer,
        createdByUid: actor['uid'] ?? '',
        createdByName: actor['name'] ?? '',
        createdByEmail: actor['email'] ?? '',
      );
      await Clipboard.setData(ClipboardData(text: link));
      nameController.clear();
      emailController.clear();
      showSnack('Invitación creada y enlace copiado al portapapeles.');
    } catch (error) {
      showSnack('No se pudo crear la invitación: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<GymInvitation> filteredInvites(List<GymInvitation> invites) {
    if (selectedStatusFilter == 'all') return invites;
    return invites.where((invite) {
      if (selectedStatusFilter == 'expired') return invite.isExpired && invite.status == 'pending';
      return invite.status == selectedStatusFilter;
    }).toList();
  }

  Future<void> copyInviteLink(GymInvitation invite) async {
    final link = service.buildInviteLink(invite.id);
    await Clipboard.setData(ClipboardData(text: link));
    showSnack('Enlace copiado al portapapeles.');
  }

  Future<void> showQrDialog(GymInvitation invite) async {
    final link = service.buildInviteLink(invite.id);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.gymSurface,
          title: Text('QR para ${invite.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: QrImageView(data: link, version: QrVersions.auto, size: 220, backgroundColor: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(invite.email, textAlign: TextAlign.center, style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cerrar')),
            FilledButton.icon(onPressed: () => copyInviteLink(invite), icon: const Icon(Icons.copy), label: const Text('Copiar enlace')),
          ],
        );
      },
    );
  }

  Future<void> revokeInvite(GymInvitation invite) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.gymSurface,
          title: const Text('Revocar invitación'),
          content: Text('¿Seguro que quieres revocar la invitación de ${invite.name}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(dialogContext, true), icon: const Icon(Icons.block), label: const Text('Revocar')),
          ],
        );
      },
    );
    if (confirm != true) return;
    final actor = await currentActor();
    await service.revokeInvite(invite.id, actorUid: actor['uid'] ?? '', actorName: actor['name'] ?? '', actorEmail: actor['email'] ?? '');
    showSnack('Invitación revocada.');
  }

  Widget trainerInviteCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(icon: Icons.badge, title: 'Invitar entrenador'),
          const SizedBox(height: 12),
          AppTextField(controller: trainerNameController, label: 'Nombre'),
          const SizedBox(height: 12),
          AppTextField(controller: trainerEmailController, label: 'Email', keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedTrainerRole,
            decoration: const InputDecoration(labelText: 'Rol'),
            items: const [
              DropdownMenuItem(value: trainerRoleTrainer, child: Text('Entrenador')),
              DropdownMenuItem(value: trainerRoleGymAdmin, child: Text('Admin gimnasio')),
            ],
            onChanged: loading ? null : (value) => setState(() => selectedTrainerRole = value ?? selectedTrainerRole),
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: loading ? null : () => createInvite(trainer: true), icon: const Icon(Icons.link), label: const Text('Crear enlace de entrenador'))),
        ],
      ),
    );
  }

  Widget clientInviteCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(icon: Icons.person_add_alt_1, title: 'Invitar cliente'),
          const SizedBox(height: 12),
          AppTextField(controller: clientNameController, label: 'Nombre'),
          const SizedBox(height: 12),
          AppTextField(controller: clientEmailController, label: 'Email', keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: loading ? null : () => createInvite(trainer: false), icon: const Icon(Icons.link), label: const Text('Crear enlace de cliente'))),
        ],
      ),
    );
  }

  Widget statsCard(InvitationStats stats) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(icon: Icons.analytics_outlined, title: 'Resumen de invitaciones'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(label: 'Total', value: stats.total.toString()),
              _MetricChip(label: 'Pendientes', value: stats.pending.toString()),
              _MetricChip(label: 'Aceptadas', value: stats.accepted.toString()),
              _MetricChip(label: 'Revocadas', value: stats.revoked.toString()),
              _MetricChip(label: 'Caducadas', value: stats.expired.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget filterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChipButton(text: 'Todas', selected: selectedStatusFilter == 'all', onTap: () => setState(() => selectedStatusFilter = 'all')),
          _FilterChipButton(text: 'Pendientes', selected: selectedStatusFilter == 'pending', onTap: () => setState(() => selectedStatusFilter = 'pending')),
          _FilterChipButton(text: 'Aceptadas', selected: selectedStatusFilter == 'accepted', onTap: () => setState(() => selectedStatusFilter = 'accepted')),
          _FilterChipButton(text: 'Revocadas', selected: selectedStatusFilter == 'revoked', onTap: () => setState(() => selectedStatusFilter = 'revoked')),
          _FilterChipButton(text: 'Caducadas', selected: selectedStatusFilter == 'expired', onTap: () => setState(() => selectedStatusFilter = 'expired')),
        ],
      ),
    );
  }

  Widget invitesList(List<GymInvitation> invites) {
    final visible = filteredInvites(invites);
    if (visible.isEmpty) {
      return AppCard(child: Text('No hay invitaciones en este filtro.', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700)));
    }
    return Column(
      children: visible.map((invite) {
        final canUse = invite.isPending;
        final statusColor = invite.isAccepted ? Colors.greenAccent : invite.isRevoked || invite.isExpired ? Colors.redAccent : context.gymPrimary;
        return AppCard(
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(invite.isClientInvite ? Icons.person : Icons.badge, color: statusColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(invite.name.isEmpty ? invite.email : invite.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text('${invite.roleLabel} · ${invite.email}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                    child: Text(invite.statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(onPressed: canUse ? () => copyInviteLink(invite) : null, icon: const Icon(Icons.copy), label: const Text('Copiar')),
                  OutlinedButton.icon(onPressed: canUse ? () => showQrDialog(invite) : null, icon: const Icon(Icons.qr_code_2), label: const Text('QR')),
                  OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent), onPressed: canUse ? () => revokeInvite(invite) : null, icon: const Icon(Icons.block), label: const Text('Revocar')),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invitaciones')),
      body: SafeArea(
        child: StreamBuilder<List<GymInvitation>>(
          stream: service.watchInvites(),
          builder: (context, snapshot) {
            final invites = snapshot.data ?? const <GymInvitation>[];
            final stats = InvitationStats.fromInvites(invites);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                statsCard(stats),
                const SizedBox(height: 12),
                trainerInviteCard(),
                const SizedBox(height: 12),
                clientInviteCard(),
                const SizedBox(height: 16),
                SectionTitle(icon: Icons.list_alt, title: 'Historial'),
                const SizedBox(height: 10),
                filterBar(),
                const SizedBox(height: 12),
                invitesList(invites),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
      child: Text('$label: $value', style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w900)),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChipButton({required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text(text),
        onSelected: (_) => onTap(),
        selectedColor: context.gymPrimary.withValues(alpha: 0.16),
        backgroundColor: context.gymSubtleSurface,
        side: BorderSide(color: selected ? context.gymPrimary : context.gymBorder),
      ),
    );
  }
}

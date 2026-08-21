import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/navigation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../services/subscription_service.dart';
import '../services/trainer_permission_service.dart';
import '../services/trainer_profile_service.dart';
import 'settings_page.dart';
import 'community_page.dart';
import 'challenges_page.dart';
import 'rankings_page.dart';
import 'notifications_page.dart';
import 'conversations_page.dart';
import 'trainer_calendar_page.dart';
import 'trainer_clients_page.dart';
import 'trainer_goals_page.dart';
import 'trainer_measurements_page.dart';
import 'trainer_progress_page.dart';
import 'trainer_routines_page.dart';
import 'trainer_trainers_page.dart';
import 'stats_backfill_page.dart';
import 'user_home_page.dart';
import 'subscription_page.dart';
import '../services/trainer_routine_service.dart';
part 'trainer_home/notifications_bell.dart';
part 'trainer_home/trainer_header.dart';
part 'trainer_home/trainer_dashboard_v2.dart';
part 'trainer_home/trainer_recent_activity_card.dart';
part 'trainer_home/trainer_stats_grid.dart';
part 'trainer_home/trainer_quick_actions.dart';
part 'trainer_home/trainer_bottom_nav.dart';
part 'trainer_home/trainer_onboarding_checklist_card.dart';
part 'trainer_home/trainer_weekly_automation_card.dart';
class TrainerHomePage extends StatelessWidget {
  final String gymId;
  final String trainerName;
  final String trainerRole;
  const TrainerHomePage({super.key, required this.gymId, required this.trainerName, this.trainerRole = 'trainer'});
  static const _permissions = TrainerPermissionService();
  bool get isGymAdmin => _permissions.isGymAdmin(trainerRole);
  void openPage(BuildContext context, Widget page) {
    AppNavigation.push(context, page);
  }
  void showLockedFeature(BuildContext context, String featureName, GymSubscriptionPlan plan) {
    final reason = _permissions.lockedFeatureReason(featureName, plan);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
  }
  String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }
  String firstName() {
    final clean = trainerName.trim();
    if (clean.isEmpty) return 'Entrenador';
    return clean.split(RegExp(r'\s+')).first;
  }
  CollectionReference<Map<String, dynamic>> collection(String name) {
    return FirebaseFirestore.instance.collection('gyms').doc(gymId).collection(name);
  }
  Future<void> openMyTraining(BuildContext context) async {
    final profile = await TrainerProfileService(gymId: gymId)
        .ensurePersonalTrainingProfile(trainerName: trainerName);
    if (profile == null || !context.mounted) return;
    openPage(
      context,
      UserHomePage(
        gymId: gymId,
        userId: profile.userId,
        userName: profile.name,
        userEmail: profile.email,
        launchedFromTrainer: true,
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    return StreamBuilder<GymSubscriptionPlan>(
      stream: SubscriptionService(gymId: gymId).watchPlan(),
      builder: (context, subscriptionSnapshot) {
        final plan = subscriptionSnapshot.data ?? GymSubscriptionPlan.fallback(gymId);
        final canUseChat = _permissions.canUseChat(plan);
        final canUseCommunity = _permissions.canUseCommunity(plan);
        final canUseChallenges = _permissions.canUseChallenges(plan);
        final canUseRankings = _permissions.canUseRankings(plan);
        final actions = [
          TrainerQuickAction(icon: Icons.self_improvement, title: 'Mi entreno', priority: true, onTap: () => openMyTraining(context)),
          TrainerQuickAction(icon: Icons.people, title: 'Clientes', priority: true, onTap: () => openPage(context, TrainerClientsPage(gymId: gymId))),
          TrainerQuickAction(icon: Icons.fitness_center, title: 'Rutinas', priority: true, onTap: () => openPage(context, TrainerRoutinesPage(gymId: gymId))),
          if (canUseChat) TrainerQuickAction(icon: Icons.chat_bubble_outline, title: 'Chat', priority: true, onTap: () => openPage(context, ConversationsPage(gymId: gymId, currentUserId: currentUid, currentUserName: trainerName, currentUserEmail: currentEmail, currentRole: 'trainer'))),
          TrainerQuickAction(icon: Icons.calendar_month, title: 'Agenda', onTap: () => openPage(context, TrainerCalendarPage(gymId: gymId))),
          TrainerQuickAction(icon: Icons.flag, title: 'Objetivos', onTap: () => openPage(context, TrainerGoalsPage(gymId: gymId))),
          TrainerQuickAction(icon: Icons.insights, title: 'Progreso', onTap: () => openPage(context, TrainerProgressPage(gymId: gymId))),
          TrainerQuickAction(icon: Icons.monitor_weight, title: 'Medidas', onTap: () => openPage(context, TrainerMeasurementsPage(gymId: gymId))),
          TrainerQuickAction(icon: canUseCommunity ? Icons.forum : Icons.lock_outline, title: 'Muro', onTap: () => canUseCommunity ? openPage(context, CommunityPage(gymId: gymId, currentUserId: currentUid, currentUserName: trainerName, currentUserEmail: currentEmail, trainerMode: true)) : showLockedFeature(context, 'Comunidad', plan)),
          if (canUseChallenges) TrainerQuickAction(icon: Icons.emoji_events, title: 'Retos', onTap: () => openPage(context, ChallengesPage(gymId: gymId, userId: currentUid, userName: trainerName, userEmail: currentEmail, trainerMode: true))),
          if (canUseRankings) TrainerQuickAction(icon: Icons.leaderboard, title: 'Ranking', onTap: () => openPage(context, RankingsPage(gymId: gymId, currentUserId: currentUid, currentUserName: trainerName, currentUserEmail: currentEmail))),
          TrainerQuickAction(icon: Icons.groups, title: 'Equipo', onTap: () => openPage(context, TrainerTrainersPage(gymId: gymId, trainerRole: trainerRole))),
          if (isGymAdmin) TrainerQuickAction(icon: Icons.sync, title: 'Recalcular', onTap: () => openPage(context, StatsBackfillPage(gymId: gymId))),
        ];
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          bottomNavigationBar: _TrainerBottomNav(onTraining: () => openMyTraining(context), onClients: () => openPage(context, TrainerClientsPage(gymId: gymId)), onRoutines: () => openPage(context, TrainerRoutinesPage(gymId: gymId)), onCommunity: () => canUseCommunity ? openPage(context, CommunityPage(gymId: gymId, currentUserId: currentUid, currentUserName: trainerName, currentUserEmail: currentEmail, trainerMode: true)) : showLockedFeature(context, 'Comunidad', plan)),
          body: Container(
            decoration: BoxDecoration(gradient: context.gymTrainerHomeGradient),
            child: SafeArea(
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 4), child: _TrainerHeader(title: 'Hola, ${firstName()}', subtitle: isGymAdmin ? 'Vista admin de ${context.gymBrandName} · plan ${plan.plan}' : 'Vista entrenador · plan ${plan.plan}', gymId: gymId, onSettings: () => openPage(context, SettingsPage(userEmail: currentEmail))))),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 22),
                  sliver: SliverList(delegate: SliverChildListDelegate([
                    if (!plan.isActive) _SubscriptionWarningCard(plan: plan),
                    if (!plan.isActive) const SizedBox(height: 12),
                    if (isGymAdmin) _SubscriptionSummaryCard(plan: plan, service: SubscriptionService(gymId: gymId), onManage: () => openPage(context, SubscriptionPage(gymId: gymId))),
                    if (isGymAdmin) const SizedBox(height: 12),
                    TrainerDashboardV2(greeting: greeting(), trainersStream: collection('trainers').snapshots(), clientsStream: collection('clients').snapshots(), routinesStream: collection('routines').snapshots(), goalsStream: collection('goals').snapshots(), userStatsStream: collection('user_stats').snapshots(), activityStream: collection('activity').orderBy('createdAt', descending: true).limit(8).snapshots(), onOpenClients: () => openPage(context, TrainerClientsPage(gymId: gymId)), onOpenRoutines: () => openPage(context, TrainerRoutinesPage(gymId: gymId)), onOpenRoutineForClient: (clientId, clientName) => openPage(context, TrainerRoutinesPage(gymId: gymId, initialClientId: clientId, initialClientName: clientName, focusCreation: true)), onOpenGoals: () => openPage(context, TrainerGoalsPage(gymId: gymId)), onOpenTrainers: () => openPage(context, TrainerTrainersPage(gymId: gymId, trainerRole: trainerRole))),
                    const SizedBox(height: 12),
                    _TrainerWeeklyAutomationCard(gymId: gymId, onOpenRoutines: () => openPage(context, TrainerRoutinesPage(gymId: gymId)), onOpenRoutineForClient: (clientId, clientName) => openPage(context, TrainerRoutinesPage(gymId: gymId, initialClientId: clientId, initialClientName: clientName, focusCreation: true))),
                    const SizedBox(height: 12),
                    _TrainerOnboardingChecklistCard(gymId: gymId, trainerName: trainerName, onOpenClients: () => openPage(context, TrainerClientsPage(gymId: gymId)), onOpenRoutines: () => openPage(context, TrainerRoutinesPage(gymId: gymId)), onOpenGoals: () => openPage(context, TrainerGoalsPage(gymId: gymId)), onOpenProgress: () => openPage(context, TrainerProgressPage(gymId: gymId)), onOpenTraining: () => openMyTraining(context)),
                    const SizedBox(height: 12),
                    _TrainerToolsPanel(actions: actions),
                  ])),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _SubscriptionSummaryCard extends StatelessWidget {
  final GymSubscriptionPlan plan;
  final SubscriptionService service;
  final VoidCallback onManage;

  const _SubscriptionSummaryCard({
    required this.plan,
    required this.service,
    required this.onManage,
  });

  String usageText(int value, int limit) =>
      limit >= 999999 ? '$value / Ilimitado' : '$value / $limit';

  double progress(int value, int limit) {
    if (limit >= 999999 || limit <= 0) return 0;
    return (value / limit).clamp(0.0, 1.0);
  }

  double rawRatio(int value, int limit) {
    if (limit >= 999999 || limit <= 0) return 0;
    return value / limit;
  }

  Widget metric(BuildContext context, String label, int value, int limit) {
    final ratio = progress(value, limit);
    final color = ratio >= 1
        ? Colors.redAccent
        : ratio >= .8
            ? Colors.orangeAccent
            : context.gymPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              usageText(value, limit),
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 7),
        if (limit < 999999)
          LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            borderRadius: BorderRadius.circular(99),
            color: color,
            backgroundColor: color.withValues(alpha: .14),
          ),
      ],
    );
  }

  Widget featureChip(
    BuildContext context,
    String label,
    bool enabled,
  ) {
    final color = enabled ? context.gymPrimary : context.gymMutedText;
    return Chip(
      avatar: Icon(
        enabled ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
        size: 18,
        color: color,
      ),
      label: Text(label),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
      backgroundColor: color.withValues(alpha: .10),
      side: BorderSide(color: color.withValues(alpha: .18)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: service.watchClientCount(),
      builder: (context, clientsSnapshot) => StreamBuilder<int>(
        stream: service.watchTrainerCount(),
        builder: (context, trainersSnapshot) {
          final clients = clientsSnapshot.data ?? 0;
          final trainers = trainersSnapshot.data ?? 0;
          final clientRatio = rawRatio(clients, plan.maxClients);
          final trainerRatio = rawRatio(trainers, plan.maxTrainers);
          final highestRatio = clientRatio > trainerRatio
              ? clientRatio
              : trainerRatio;
          final limitReached = highestRatio >= 1;
          final nearLimit = highestRatio >= .8 && !limitReached;
          final alertColor = limitReached
              ? Colors.redAccent
              : Colors.orangeAccent;

          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: context.gymPrimary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: context.gymPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Suscripcion GymFlow',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${plan.displayPlan} · ${plan.displayStatus}',
                            style: TextStyle(
                              color: context.gymMutedText,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (plan.renewalDate.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Renovacion: ${plan.renewalDate}',
                    style: TextStyle(
                      color: context.gymMutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                metric(context, 'Clientes', clients, plan.maxClients),
                const SizedBox(height: 14),
                metric(
                  context,
                  'Entrenadores activos',
                  trainers,
                  plan.maxTrainers,
                ),
                if (nearLimit || limitReached) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: alertColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: alertColor.withValues(alpha: .55),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              limitReached
                                  ? Icons.error_outline_rounded
                                  : Icons.warning_amber_rounded,
                              color: alertColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                limitReached
                                    ? 'Has alcanzado el limite de tu plan.'
                                    : 'Estas cerca del limite de tu plan.',
                                style: TextStyle(
                                  color: alertColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          limitReached
                              ? 'Actualiza la suscripcion para seguir creciendo.'
                              : 'Te recomendamos actualizar antes de alcanzar el limite.',
                          style: TextStyle(color: context.gymMutedText),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Funciones incluidas',
                  style: TextStyle(
                    color: context.gymText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    featureChip(
                      context,
                      'Comunidad',
                      plan.communityEnabled,
                    ),
                    featureChip(context, 'Chat', plan.chatEnabled),
                    featureChip(
                      context,
                      'Rankings',
                      plan.rankingsEnabled,
                    ),
                    featureChip(
                      context,
                      'Retos',
                      plan.challengesEnabled,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: (nearLimit || limitReached)
                      ? FilledButton.icon(
                          onPressed: onManage,
                          icon: const Icon(Icons.upgrade_rounded),
                          label: Text(
                            limitReached
                                ? 'Ampliar plan ahora'
                                : 'Ver opciones de ampliacion',
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: onManage,
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text('Gestionar suscripcion'),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SubscriptionWarningCard extends StatelessWidget {
  final GymSubscriptionPlan plan;
  const _SubscriptionWarningCard({required this.plan});
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
              SizedBox(width: 10),
              Expanded(child: Text('Pago pendiente de la suscripción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 10),
          Text('Estado actual: ${plan.displayStatus}. Algunas funciones ya están bloqueadas. Actualiza la suscripción para recuperar el acceso completo.', style: TextStyle(color: context.gymText)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => AppNavigation.push(context, SubscriptionPage(gymId: plan.gymId)),
              icon: const Icon(Icons.credit_card),
              label: const Text('Actualizar suscripción'),
            ),
          ),
        ],
      ),
    );
  }
}
class _TrainerToolsPanel extends StatefulWidget {
  final List<TrainerQuickAction> actions;
  const _TrainerToolsPanel({required this.actions});
  @override
  State<_TrainerToolsPanel> createState() => _TrainerToolsPanelState();
}
class _TrainerToolsPanelState extends State<_TrainerToolsPanel> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final visibleActions = expanded ? widget.actions : widget.actions.where((action) => action.priority).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => setState(() => expanded = !expanded),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.42 : 0.62), borderRadius: BorderRadius.circular(24)),
              child: Row(
                children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(17)), child: Icon(Icons.grid_view_rounded, color: context.gymPrimary, size: 21)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(expanded ? 'Todas las herramientas' : 'Herramientas rápidas', style: TextStyle(color: context.gymText, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                        const SizedBox(height: 2),
                        Text(expanded ? 'Ocultar herramientas secundarias' : 'Clientes, rutinas, chat y más', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Text(expanded ? 'Menos' : 'Ver más', style: TextStyle(color: context.gymPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 4),
                  Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: context.gymPrimary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TrainerQuickActionGrid(actions: visibleActions),
      ],
    );
  }
}

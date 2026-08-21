import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/navigation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../services/points_service.dart';
import '../services/achievement_service.dart';
import '../services/notification_service.dart';
import 'user_achievements_page.dart';
import 'user_calendar_page.dart';
import 'user_goals_page.dart';
import 'user_history_page.dart';
import 'user_measurements_page.dart';
import 'user_progress_page.dart';
import 'user_progress_overview_page.dart';
import 'user_records_page.dart';
import 'user_weekly_summary_page.dart';
import 'settings_page.dart';
import 'community_page.dart';
import 'challenges_page.dart';
import 'rankings_page.dart';
import 'hall_of_fame_page.dart';
import 'conversations_page.dart';
import 'user_routines_page.dart';
import 'progress_photos_page.dart';

part 'user_home/next_step_card.dart';
part 'user_home/onboarding_checklist_card.dart';
part 'user_home/adaptive_home_sections.dart';
part 'user_home/gamification_retention_card.dart';
part 'user_home/primary_actions_card.dart';
part 'user_home/secondary_actions_card.dart';
part 'user_home/home_header.dart';
part 'user_home/home_activity_feed.dart';
part 'user_home/section_title.dart';
part 'user_home/quick_actions.dart';
part 'user_home/user_bottom_nav.dart';

class UserHomePage extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;
  final bool launchedFromTrainer;

  const UserHomePage({
    super.key,
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.launchedFromTrainer = false,
  });

  void openPage(BuildContext context, Widget page) {
    AppNavigation.push(context, page);
  }

  String firstName() {
    final clean = userName.trim();
    if (clean.isEmpty) return 'Usuario';
    return clean.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      QuickAction(
        icon: Icons.fitness_center,
        title: 'Rutinas',
        onTap: () => openPage(
          context,
          UserRoutinesPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail),
        ),
      ),
      QuickAction(
        icon: Icons.chat_bubble_outline,
        title: 'Chat',
        onTap: () => openPage(
          context,
          ConversationsPage(
            gymId: gymId,
            currentUserId: userId,
            currentUserName: userName,
            currentUserEmail: userEmail,
            currentRole: 'user',
          ),
        ),
      ),
      QuickAction(
        icon: Icons.groups,
        title: 'Comunidad',
        onTap: () => openPage(
          context,
          CommunityPage(gymId: gymId, currentUserId: userId, currentUserName: userName, currentUserEmail: userEmail),
        ),
      ),
      QuickAction(
        icon: Icons.emoji_events,
        title: 'Retos',
        onTap: () => openPage(
          context,
          ChallengesPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail),
        ),
      ),
      QuickAction(
        icon: Icons.leaderboard,
        title: 'Ranking',
        onTap: () => openPage(
          context,
          RankingsPage(gymId: gymId, currentUserId: userId, currentUserName: userName, currentUserEmail: userEmail),
        ),
      ),
      QuickAction(
        icon: Icons.emoji_events,
        title: 'Fama',
        onTap: () => openPage(
          context,
          HallOfFamePage(gymId: gymId, currentUserId: userId, currentUserName: userName, currentUserEmail: userEmail),
        ),
      ),
      QuickAction(
        icon: Icons.military_tech,
        title: 'Logros',
        onTap: () => openPage(context, UserAchievementsPage(gymId: gymId, userId: userId, userEmail: userEmail)),
      ),
      QuickAction(
        icon: Icons.calendar_month,
        title: 'Agenda',
        onTap: () => openPage(context, UserCalendarPage(gymId: gymId, userEmail: userEmail)),
      ),
      QuickAction(
        icon: Icons.flag,
        title: 'Objetivos',
        onTap: () => openPage(context, UserGoalsPage(gymId: gymId, userEmail: userEmail)),
      ),
      QuickAction(
        icon: Icons.monitor_weight,
        title: 'Medidas',
        onTap: () => openPage(context, UserMeasurementsPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail)),
      ),
      QuickAction(
        icon: Icons.workspace_premium,
        title: 'Récords',
        onTap: () => openPage(context, UserRecordsPage(gymId: gymId, userId: userId)),
      ),
      QuickAction(
        icon: Icons.trending_up,
        title: 'Evolución',
        onTap: () => openPage(context, UserProgressPage(gymId: gymId, userId: userId)),
      ),
      QuickAction(
        icon: Icons.history,
        title: 'Historial',
        onTap: () => openPage(context, UserHistoryPage(gymId: gymId, userId: userId)),
      ),
      QuickAction(
        icon: Icons.calendar_view_week,
        title: 'Resumen',
        onTap: () => openPage(context, UserWeeklySummaryPage(gymId: gymId, userId: userId)),
      ),
    ];

    final primaryActions = [
      QuickAction(
        icon: Icons.fitness_center_rounded,
        title: 'Entrenar',
        onTap: () => openPage(context, UserRoutinesPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail)),
      ),
      QuickAction(
        icon: Icons.emoji_events_rounded,
        title: 'Retos',
        onTap: () => openPage(context, ChallengesPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail)),
      ),
      QuickAction(
        icon: Icons.groups_rounded,
        title: 'Comunidad',
        onTap: () => openPage(context, CommunityPage(gymId: gymId, currentUserId: userId, currentUserName: userName, currentUserEmail: userEmail)),
      ),
      QuickAction(
        icon: Icons.chat_bubble_rounded,
        title: 'Chat',
        onTap: () => openPage(
          context,
          ConversationsPage(gymId: gymId, currentUserId: userId, currentUserName: userName, currentUserEmail: userEmail, currentRole: 'user'),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: _UserBottomNav(
        onRutinas: () => openPage(context, UserRoutinesPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail)),
        onProgreso: () => openPage(context, UserProgressOverviewPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail)),
        onComunidad: () => openPage(context, CommunityPage(gymId: gymId, currentUserId: userId, currentUserName: userName, currentUserEmail: userEmail)),
        onPerfil: () => openPage(context, SettingsPage(userEmail: userEmail)),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: context.gymHomeGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (launchedFromTrainer) ...[
                        _TrainerReturnBar(onReturn: () => Navigator.pop(context)),
                        const SizedBox(height: 10),
                      ],
                      _HomeHeader(
                        gymId: gymId,
                        userId: userId,
                        userEmail: userEmail,
                        name: firstName(),
                        onSettings: () => openPage(context, SettingsPage(userEmail: userEmail)),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 22),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _PrimaryActionsCard(actions: primaryActions),
                    const SizedBox(height: 12),
                    _GamificationRetentionCard(
                      gymId: gymId,
                      userId: userId,
                      userName: userName,
                      userEmail: userEmail,
                      onOpenRoutines: () => openPage(context, UserRoutinesPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail)),
                      onOpenChallenges: () => openPage(context, ChallengesPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail)),
                      onOpenAchievements: () => openPage(context, UserAchievementsPage(gymId: gymId, userId: userId, userEmail: userEmail)),
                      onOpenGoals: () => openPage(context, UserGoalsPage(gymId: gymId, userEmail: userEmail)),
                    ),
                    const SizedBox(height: 12),
                    _OnboardingChecklistCard(
                      gymId: gymId,
                      userId: userId,
                      userName: userName,
                      userEmail: userEmail,
                      onOpenProfile: () => openPage(context, SettingsPage(userEmail: userEmail)),
                      onOpenPhotos: () => openPage(context, ProgressPhotosPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail)),
                      onOpenRoutines: () => openPage(context, UserRoutinesPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail)),
                      onOpenGoals: () => openPage(context, UserGoalsPage(gymId: gymId, userEmail: userEmail)),
                      onOpenChallenges: () => openPage(context, ChallengesPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail)),
                      onOpenRecords: () => openPage(context, UserRecordsPage(gymId: gymId, userId: userId)),
                    ),
                    const SizedBox(height: 12),
                    _AdaptiveHomeSections(
                      gymId: gymId,
                      userId: userId,
                      userName: userName,
                      userEmail: userEmail,
                      primaryActions: primaryActions,
                      secondaryActions: actions,
                      onOpenCommunity: () => openPage(
                        context,
                        CommunityPage(gymId: gymId, currentUserId: userId, currentUserName: userName, currentUserEmail: userEmail),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainerReturnBar extends StatelessWidget {
  final VoidCallback onReturn;

  const _TrainerReturnBar({required this.onReturn});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onReturn,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.46 : 0.68),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_rounded, color: context.gymPrimary, size: 19),
              const SizedBox(width: 8),
              Text(
                'Volver al panel entrenador',
                style: TextStyle(color: context.gymPrimary, fontSize: 12.5, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

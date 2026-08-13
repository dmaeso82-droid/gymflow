import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../features/user_dashboard.dart';
import 'user_achievements_page.dart';
import 'user_calendar_page.dart';
import 'user_goals_page.dart';
import 'user_history_page.dart';
import 'user_measurements_page.dart';
import 'user_progress_page.dart';
import 'user_records_page.dart';
import 'user_weekly_summary_page.dart';
import 'settings_page.dart';
import 'community_page.dart';
import 'challenges_page.dart';
import 'rankings_page.dart';
import 'hall_of_fame_page.dart';
import 'conversations_page.dart';
import 'user_routines_page.dart';

class UserHomePage extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userName;
  final String userEmail;

  const UserHomePage({
    super.key,
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  void openPage(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
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
        icon: Icons.emoji_events_rounded,
        title: 'Retos',
        onTap: () => openPage(context, ChallengesPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail)),
      ),
      QuickAction(
        icon: Icons.chat_bubble_rounded,
        title: 'Chat',
        onTap: () => openPage(
          context,
          ConversationsPage(gymId: gymId, currentUserId: userId, currentUserName: userName, currentUserEmail: userEmail, currentRole: 'user'),
        ),
      ),
      QuickAction(
        icon: Icons.calendar_view_week_rounded,
        title: 'Semana',
        onTap: () => openPage(context, UserWeeklySummaryPage(gymId: gymId, userId: userId)),
      ),
      QuickAction(
        icon: Icons.groups_rounded,
        title: 'Comunidad',
        onTap: () => openPage(context, CommunityPage(gymId: gymId, currentUserId: userId, currentUserName: userName, currentUserEmail: userEmail)),
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: _UserBottomNav(
        onRutinas: () => openPage(context, UserRoutinesPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail)),
        onRetos: () => openPage(context, ChallengesPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail)),
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
                  child: _HomeHeader(
                    name: firstName(),
                    onSettings: () => openPage(context, SettingsPage(userEmail: userEmail)),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 22),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _NextStepCard(
                      gymId: gymId,
                      userId: userId,
                      userEmail: userEmail,
                      onOpenRoutines: () => openPage(context, UserRoutinesPage(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail)),
                      onOpenGoals: () => openPage(context, UserGoalsPage(gymId: gymId, userEmail: userEmail)),
                      onOpenRanking: () => openPage(context, RankingsPage(gymId: gymId, currentUserId: userId, currentUserName: userName, currentUserEmail: userEmail)),
                    ),
                    SizedBox(height: 12),
                    _PrimaryActionsCard(actions: primaryActions),
                    SizedBox(height: 12),
                    UserDashboard(gymId: gymId, userId: userId, userName: userName, userEmail: userEmail),
                    SizedBox(height: 12),
                    _SecondaryActionsCard(actions: actions),
                    SizedBox(height: 12),
                    _HomeActivityFeed(
                      gymId: gymId,
                      userId: userId,
                      userEmail: userEmail,
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


class _NextStepCard extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userEmail;
  final VoidCallback onOpenRoutines;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenRanking;
  const _NextStepCard({
    required this.gymId,
    required this.userId,
    required this.userEmail,
    required this.onOpenRoutines,
    required this.onOpenGoals,
    required this.onOpenRanking,
  });

  DocumentReference<Map<String, dynamic>> get statsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('user_stats').doc(userId);
  DocumentReference<Map<String, dynamic>> get leaderboardRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('leaderboard').doc(userId);

  int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String lastWorkoutText(dynamic value) {
    if (value is! Timestamp) return 'Aún no hay entrenos registrados';
    final date = value.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final workoutDay = DateTime(date.year, date.month, date.day);
    final days = today.difference(workoutDay).inDays;
    if (days == 0) return 'Has entrenado hoy';
    if (days == 1) return 'Último entreno ayer';
    return 'Último entreno hace $days días';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: statsRef.snapshots(),
      builder: (context, statsSnapshot) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: leaderboardRef.snapshots(),
          builder: (context, leaderboardSnapshot) {
            final stats = statsSnapshot.data?.data() ?? {};
            final leaderboard = leaderboardSnapshot.data?.data() ?? {};
            final workouts = intValue(stats['workouts']);
            final currentStreak = intValue(stats['currentStreak']);
            final points = intValue(stats['points']);
            final monthlyPoints = intValue(leaderboard['monthlyPoints']);
            final lastWorkout = stats['lastWorkout'];
            final hasTrained = lastWorkout is Timestamp;
            final title = hasTrained ? 'Sigue tu ritmo' : 'Empieza tu primer entreno';
            final subtitle = hasTrained
                ? '${lastWorkoutText(lastWorkout)} · $currentStreak días de racha · $points pts'
                : 'Abre tus rutinas y registra tu primer entrenamiento.';
            final buttonText = hasTrained ? 'Ir al entreno' : 'Ver rutinas';
            return AppCard(
              padding: const EdgeInsets.all(16),
              radius: 28,
              gradient: context.gymHeroGradient,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(19)),
                        child: Icon(hasTrained ? Icons.local_fire_department_rounded : Icons.play_arrow_rounded, color: context.gymPrimary, size: 28),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Tu próximo paso', style: TextStyle(color: context.gymPrimary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.7)),
                          SizedBox(height: 4),
                          Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.0)),
                          SizedBox(height: 5),
                          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 13, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _MiniProgressPill(icon: Icons.fitness_center_rounded, label: 'Entrenos', value: workouts.toString())),
                      SizedBox(width: 8),
                      Expanded(child: _MiniProgressPill(icon: Icons.emoji_events_rounded, label: 'Mes', value: '$monthlyPoints pts')),
                    ],
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: FilledButton.icon(onPressed: onOpenRoutines, icon: Icon(Icons.play_circle_fill_rounded), label: Text(buttonText))),
                      SizedBox(width: 8),
                      IconButton.filledTonal(onPressed: onOpenRanking, icon: Icon(Icons.leaderboard_rounded), tooltip: 'Ver ranking'),
                      SizedBox(width: 8),
                      IconButton.filledTonal(onPressed: onOpenGoals, icon: Icon(Icons.flag_rounded), tooltip: 'Ver objetivos'),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MiniProgressPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MiniProgressPill({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: context.gymSubtleSurface.withValues(alpha: 0.86), borderRadius: BorderRadius.circular(17), border: Border.all(color: context.gymBorder)),
      child: Row(children: [
        Icon(icon, color: context.gymPrimary, size: 18),
        SizedBox(width: 7),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

class _PrimaryActionsCard extends StatelessWidget {
  final List<QuickAction> actions;
  const _PrimaryActionsCard({required this.actions});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      radius: 24,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionTitle(icon: Icons.touch_app_rounded, title: 'Accesos principales'),
        SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 8.0;
            final width = (constraints.maxWidth - spacing) / 2;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: actions.map((action) => SizedBox(width: width, child: _PrimaryActionTile(action: action))).toList(),
            );
          },
        ),
      ]),
    );
  }
}

class _PrimaryActionTile extends StatelessWidget {
  final QuickAction action;
  const _PrimaryActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: action.onTap,
        child: Ink(
          height: 70,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.gymPrimary.withValues(alpha: context.gymIsDark ? 0.24 : 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: context.gymPrimary.withValues(alpha: 0.28))),
          child: Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(15)), child: Icon(action.icon, color: context.gymPrimaryStrong, size: 22)),
            SizedBox(width: 10),
            Expanded(child: Text(action.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900))),
          ]),
        ),
      ),
    );
  }
}

class _SecondaryActionsCard extends StatefulWidget {
  final List<QuickAction> actions;
  const _SecondaryActionsCard({required this.actions});

  @override
  State<_SecondaryActionsCard> createState() => _SecondaryActionsCardState();
}

class _SecondaryActionsCardState extends State<_SecondaryActionsCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final visibleActions = expanded ? widget.actions : widget.actions.take(12).toList();
    return AppCard(
      padding: const EdgeInsets.all(12),
      radius: 24,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _SectionTitle(icon: Icons.grid_view_rounded, title: 'Más herramientas')),
          TextButton.icon(
            onPressed: () => setState(() => expanded = !expanded),
            icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(expanded ? 'Menos' : 'Ver más'),
          ),
        ]),
        SizedBox(height: 10),
        QuickActionGrid(actions: visibleActions),
      ]),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String name;
  final VoidCallback onSettings;

  const _HomeHeader({required this.name, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: context.gymHeroGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.gymFitnessAccent.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.gymFitnessAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.local_fire_department, color: context.gymPrimary, size: 26),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DALAIGYM PERFORMANCE', style: TextStyle(color: context.gymPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                SizedBox(height: 5),
                Text('Hola, $name', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, height: 1.0)),
                SizedBox(height: 5),
                Text('Tu progreso empieza hoy', style: TextStyle(color: context.gymMutedText, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: context.gymSubtleSurface),
            onPressed: onSettings,
            icon: Icon(Icons.settings),
          ),
        ],
      ),
    );
  }
}

class _HomeActivityFeed extends StatelessWidget {
  final String gymId;
  final String userId;
  final String userEmail;
  final VoidCallback onOpenCommunity;

  const _HomeActivityFeed({
    required this.gymId,
    required this.userId,
    required this.userEmail,
    required this.onOpenCommunity,
  });

  CollectionReference<Map<String, dynamic>> get activityRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('activity');
  CollectionReference<Map<String, dynamic>> get postsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('community_posts');

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final itemDay = DateTime(date.year, date.month, date.day);
      if (itemDay == today) return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    }
    return '';
  }

  IconData iconForType(String type) {
    if (type.contains('record')) return Icons.workspace_premium;
    if (type.contains('challenge') || type.contains('duel')) return Icons.emoji_events;
    if (type.contains('goal')) return Icons.flag;
    if (type.contains('routine') || type.contains('workout')) return Icons.fitness_center;
    if (type.contains('photo')) return Icons.photo_camera;
    return Icons.bolt;
  }

  String titleFromData(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final user = data['userName']?.toString().trim().isNotEmpty == true
        ? data['userName'].toString()
        : data['user']?.toString().trim().isNotEmpty == true
            ? data['user'].toString()
            : 'DalaiGym';
    final message = data['message']?.toString().trim() ?? '';
    final title = data['title']?.toString().trim() ?? '';
    if (title.isNotEmpty) return title;
    if (message.isNotEmpty) return message;
    if (type.contains('record')) return '$user consiguió un nuevo récord';
    if (type.contains('challenge')) return '$user completó un reto';
    if (type.contains('duel')) return '$user inició un duelo';
    if (type.contains('goal')) return '$user actualizó un objetivo';
    if (type.contains('routine') || type.contains('workout')) return '$user completó un entrenamiento';
    return '$user publicó una actualización';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: activityRef.orderBy('createdAt', descending: true).limit(4).snapshots(),
      builder: (context, activitySnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: postsRef.orderBy('createdAt', descending: true).limit(4).snapshots(),
          builder: (context, postsSnapshot) {
            final items = <_FeedItem>[];
            for (final doc in activitySnapshot.data?.docs ?? []) {
              final data = doc.data();
              items.add(_FeedItem(
                icon: iconForType(data['type']?.toString() ?? ''),
                title: titleFromData(data),
                subtitle: formatDate(data['createdAt']),
                createdAt: data['createdAt'],
              ));
            }
            for (final doc in postsSnapshot.data?.docs ?? []) {
              final data = doc.data();
              items.add(_FeedItem(
                icon: iconForType(data['type']?.toString() ?? ''),
                title: titleFromData(data),
                subtitle: formatDate(data['createdAt']),
                createdAt: data['createdAt'],
              ));
            }
            items.sort((a, b) {
              final aMillis = a.createdAt is Timestamp ? (a.createdAt as Timestamp).millisecondsSinceEpoch : 0;
              final bMillis = b.createdAt is Timestamp ? (b.createdAt as Timestamp).millisecondsSinceEpoch : 0;
              return bMillis.compareTo(aMillis);
            });
            final visible = items.take(4).toList();
            return AppCard(
              padding: const EdgeInsets.all(14),
              radius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _SectionTitle(icon: Icons.dynamic_feed, title: 'Actividad reciente')),
                      TextButton(onPressed: onOpenCommunity, child: Text('Ver')),
                    ],
                  ),
                  SizedBox(height: 10),
                  if (activitySnapshot.hasError || postsSnapshot.hasError)
                    Text('No se ha podido cargar la actividad reciente.', style: TextStyle(color: context.gymMutedText))
                  else if (visible.isEmpty)
                    Text('Cuando haya entrenos, retos, récords o publicaciones, aparecerán aquí.', style: TextStyle(color: context.gymMutedText))
                  else
                    ...visible.map((item) => _FeedTile(item: item)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _FeedItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final dynamic createdAt;

  const _FeedItem({required this.icon, required this.title, required this.subtitle, required this.createdAt});
}

class _FeedTile extends StatelessWidget {
  final _FeedItem item;

  const _FeedTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.gymBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.gymFitnessAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(item.icon, color: context.gymPrimary, size: 19),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
          if (item.subtitle.isNotEmpty) ...[
            SizedBox(width: 8),
            Text(item.subtitle, style: TextStyle(color: context.gymMutedText.withValues(alpha: 0.70), fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: context.gymPrimary, size: 20),
        ),
        SizedBox(width: 10),
        Expanded(child: Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
      ],
    );
  }
}

class QuickAction {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const QuickAction({required this.icon, required this.title, required this.onTap});
}

class QuickActionGrid extends StatelessWidget {
  final List<QuickAction> actions;

  const QuickActionGrid({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 430 ? 4 : constraints.maxWidth < 720 ? 5 : 6;
        const spacing = 7.0;
        final tileWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions.map((action) => SizedBox(width: tileWidth, child: QuickActionTile(action: action))).toList(),
        );
      },
    );
  }
}

class QuickActionTile extends StatelessWidget {
  final QuickAction action;

  const QuickActionTile({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: action.onTap,
        child: Ink(
          height: 66,
          decoration: BoxDecoration(
            color: context.gymSubtleSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.gymBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, color: context.gymPrimary, size: 21),
              SizedBox(height: 5),
              Text(
                action.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.2, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserBottomNav extends StatelessWidget {
  final VoidCallback onRutinas;
  final VoidCallback onRetos;
  final VoidCallback onComunidad;
  final VoidCallback onPerfil;

  const _UserBottomNav({
    required this.onRutinas,
    required this.onRetos,
    required this.onComunidad,
    required this.onPerfil,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: context.gymElevatedSurface.withValues(alpha: context.gymIsDark ? 0.96 : 0.98),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.gymBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.34), blurRadius: 22, offset: const Offset(0, 10))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const _NavItem(icon: Icons.home_rounded, label: 'Inicio', active: true),
            _NavItem(icon: Icons.fitness_center, label: 'Rutinas', onTap: onRutinas),
            _NavItem(icon: Icons.emoji_events, label: 'Retos', onTap: onRetos),
            _NavItem(icon: Icons.groups, label: 'Comunidad', onTap: onComunidad),
            _NavItem(icon: Icons.person, label: 'Perfil', onTap: onPerfil),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _NavItem({required this.icon, required this.label, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? context.gymPrimary : context.gymMutedText;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}




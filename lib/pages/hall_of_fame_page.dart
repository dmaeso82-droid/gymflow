import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/points_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/profile_avatar.dart';
import 'user_profile_page.dart';

class HallOfFamePage extends StatelessWidget {
  final String gymId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserEmail;

  const HallOfFamePage({
    super.key,
    required this.gymId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserEmail,
  });

  CollectionReference<Map<String, dynamic>> get leaderboardRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('leaderboard');
  CollectionReference<Map<String, dynamic>> get userStatsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('user_stats');
  CollectionReference<Map<String, dynamic>> get achievementsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('user_achievements');
  CollectionReference<Map<String, dynamic>> get challengesRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('challenge_completions');
  CollectionReference<Map<String, dynamic>> get duelsRef => FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('duels');

  int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String userKey(Map<String, dynamic> data) {
    final uid = data['userId']?.toString() ?? data['winnerId']?.toString() ?? '';
    final email = (data['userEmail'] ?? data['winnerEmail'] ?? '').toString().toLowerCase();
    if (uid.trim().isNotEmpty) return uid.trim();
    return email.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  String userName(Map<String, dynamic> data) {
    final values = [data['userName'], data['winnerName'], data['name']];
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return 'Usuario';
  }

  String userId(Map<String, dynamic> data) => (data['userId'] ?? data['winnerId'] ?? '').toString();
  String userEmail(Map<String, dynamic> data) => (data['userEmail'] ?? data['winnerEmail'] ?? '').toString().toLowerCase();

  void addGrouped(Map<String, _FameEntry> map, Map<String, dynamic> data, int delta) {
    final key = userKey(data);
    if (key.isEmpty) return;
    final entry = map.putIfAbsent(
      key,
      () => _FameEntry(
        userId: userId(data),
        userName: userName(data),
        userEmail: userEmail(data),
      ),
    );
    entry.value += delta;
  }

  List<_FameEntry> sortedEntries(Iterable<_FameEntry> entries, Map<String, int> allTimePoints) {
    final list = entries.where((entry) => entry.value > 0).toList();
    for (final entry in list) {
      final key = entry.userId.isNotEmpty ? entry.userId : entry.userEmail.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      entry.allTimePoints = allTimePoints[key] ?? 0;
    }
    list.sort((a, b) => b.value.compareTo(a.value));
    return list.take(5).toList();
  }

  Future<List<_FameCategory>> loadHallOfFame() async {
    final results = await Future.wait([
      leaderboardRef.get(),
      userStatsRef.get(),
      achievementsRef.get(),
      challengesRef.get(),
      duelsRef.get(),
    ]);

    final leaderboardSnapshot = results[0];
    final statsSnapshot = results[1];
    final achievementsSnapshot = results[2];
    final challengesSnapshot = results[3];
    final duelsSnapshot = results[4];

    final allTimePoints = <String, int>{};
    final pointsEntries = <_FameEntry>[];
    for (final doc in leaderboardSnapshot.docs) {
      final data = doc.data();
      final points = intValue(data['allTimePoints']);
      final key = doc.id;
      allTimePoints[key] = points;
      pointsEntries.add(_FameEntry(
        userId: data['userId']?.toString() ?? doc.id,
        userName: data['userName']?.toString() ?? 'Usuario',
        userEmail: (data['userEmail'] ?? '').toString().toLowerCase(),
        value: points,
        allTimePoints: points,
      ));
    }
    pointsEntries.sort((a, b) => b.value.compareTo(a.value));

    final streakEntries = <_FameEntry>[];
    for (final doc in statsSnapshot.docs) {
      final data = doc.data();
      final best = intValue(data['bestStreak']);
      final current = intValue(data['currentStreak']);
      final value = best > current ? best : current;
      if (value <= 0) continue;
      final key = doc.id;
      streakEntries.add(_FameEntry(
        userId: data['userId']?.toString() ?? doc.id,
        userName: data['userName']?.toString() ?? 'Usuario',
        userEmail: (data['userEmail'] ?? '').toString().toLowerCase(),
        value: value,
        allTimePoints: allTimePoints[key] ?? 0,
      ));
    }
    streakEntries.sort((a, b) => b.value.compareTo(a.value));

    final achievementsGrouped = <String, _FameEntry>{};
    for (final doc in achievementsSnapshot.docs) {
      addGrouped(achievementsGrouped, doc.data(), 1);
    }

    final challengesGrouped = <String, _FameEntry>{};
    for (final doc in challengesSnapshot.docs) {
      addGrouped(challengesGrouped, doc.data(), 1);
    }

    final duelsGrouped = <String, _FameEntry>{};
    for (final doc in duelsSnapshot.docs) {
      final data = doc.data();
      if ((data['status'] ?? '').toString() != 'completed') continue;
      final winnerId = data['winnerId']?.toString() ?? '';
      if (winnerId.isEmpty) continue;
      addGrouped(duelsGrouped, {
        'userId': winnerId,
        'userName': data['winnerName']?.toString() ?? 'Ganador',
        'userEmail': data['winnerEmail']?.toString() ?? '',
      }, 1);
    }

    return [
      _FameCategory(
        icon: Icons.emoji_events,
        title: 'Rey de DalaiGym',
        subtitle: 'Más puntos históricos acumulados',
        unit: 'puntos',
        entries: pointsEntries.take(5).toList(),
      ),
      _FameCategory(
        icon: Icons.local_fire_department,
        title: 'Maestro de las rachas',
        subtitle: 'Mejor racha registrada',
        unit: 'días',
        entries: streakEntries.take(5).toList(),
      ),
      _FameCategory(
        icon: Icons.workspace_premium,
        title: 'Coleccionista de logros',
        subtitle: 'Más logros desbloqueados',
        unit: 'logros',
        entries: sortedEntries(achievementsGrouped.values, allTimePoints),
      ),
      _FameCategory(
        icon: Icons.flag,
        title: 'Cazador de retos',
        subtitle: 'Más retos completados',
        unit: 'retos',
        entries: sortedEntries(challengesGrouped.values, allTimePoints),
      ),
      _FameCategory(
        icon: Icons.sports_mma,
        title: 'Campeón de duelos',
        subtitle: 'Más duelos ganados',
        unit: 'victorias',
        entries: sortedEntries(duelsGrouped.values, allTimePoints),
      ),
    ];
  }

  void openProfile(BuildContext context, _FameEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          gymId: gymId,
          userId: entry.userId,
          userName: entry.userName,
          userEmail: entry.userEmail,
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          currentUserEmail: currentUserEmail,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hall of Fame')),
      body: Container(
        decoration: BoxDecoration(gradient: context.gymHomeGradient),
        child: SafeArea(
          child: FutureBuilder<List<_FameCategory>>(
            future: loadHallOfFame(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppCard(child: Text('No se ha podido cargar el Salón de la Fama.', style: TextStyle(color: context.gymMutedText))),
                );
              }
              final categories = snapshot.data ?? [];
              return ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    radius: 28,
                    gradient: context.gymHeroGradient,
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(color: Colors.amberAccent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
                          child: const Icon(Icons.emoji_events, color: Colors.amberAccent, size: 30),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Salón de la Fama DalaiGym', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, height: 1.0, color: context.gymText)),
                              const SizedBox(height: 6),
                              Text('Los grandes referentes del gimnasio en puntos, rachas, logros, retos y duelos.', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...categories.map((category) => _FameCategoryCard(category: category, onOpenProfile: (entry) => openProfile(context, entry))),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FameCategoryCard extends StatelessWidget {
  final _FameCategory category;
  final void Function(_FameEntry entry) onOpenProfile;

  const _FameCategoryCard({required this.category, required this.onOpenProfile});

  @override
  Widget build(BuildContext context) {
    final champion = category.entries.isEmpty ? null : category.entries.first;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
                child: Icon(category.icon, color: context.gymPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.gymText)),
                    const SizedBox(height: 2),
                    Text(category.subtitle, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (champion == null)
            Text('Todavía no hay datos suficientes para esta categoría.', style: TextStyle(color: context.gymMutedText))
          else ...[
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onOpenProfile(champion),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.34)),
                ),
                child: Row(
                  children: [
                    const Text('👑', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 10),
                    ProfileAvatar(name: champion.userName, size: 42),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${prestigeForPoints(champion.allTimePoints).badge} ${champion.userName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymText, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text(prestigeForPoints(champion.allTimePoints).label, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Text('${champion.value} ${category.unit}', style: TextStyle(color: context.gymPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...category.entries.skip(1).take(4).toList().asMap().entries.map((item) {
              final position = item.key + 2;
              final entry = item.value;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onOpenProfile(entry),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 34, child: Text('#$position', style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w900))),
                      ProfileAvatar(name: entry.userName, size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${prestigeForPoints(entry.allTimePoints).badge} ${entry.userName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: context.gymText)),
                            Text(prestigeForPoints(entry.allTimePoints).label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      Text('${entry.value}', style: TextStyle(color: context.gymPrimary, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _FameCategory {
  final IconData icon;
  final String title;
  final String subtitle;
  final String unit;
  final List<_FameEntry> entries;

  const _FameCategory({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.unit,
    required this.entries,
  });
}

class _FameEntry {
  final String userId;
  final String userName;
  final String userEmail;
  int value;
  int allTimePoints;

  _FameEntry({
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.value = 0,
    this.allTimePoints = 0,
  });
}

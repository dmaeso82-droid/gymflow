import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'premium_reward_dialog.dart';

class PremiumRewardsListener extends StatefulWidget {
  final Widget child;

  const PremiumRewardsListener({super.key, required this.child});

  @override
  State<PremiumRewardsListener> createState() => _PremiumRewardsListenerState();
}

class _PremiumRewardsListenerState extends State<PremiumRewardsListener> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? rewardSubscription;
  bool showingReward = false;
  String? activeGymId;
  final handledIds = <String>{};

  @override
  void initState() {
    super.initState();
    listenToUserGym();
  }

  @override
  void didUpdateWidget(covariant PremiumRewardsListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      stopListeners();
    }
  }

  @override
  void dispose() {
    stopListeners();
    super.dispose();
  }

  void stopListeners() {
    userSubscription?.cancel();
    rewardSubscription?.cancel();
    userSubscription = null;
    rewardSubscription = null;
    activeGymId = null;
    handledIds.clear();
  }

  void listenToUserGym() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    userSubscription?.cancel();
    userSubscription = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((snapshot) {
      final gymId = snapshot.data()?['gymId']?.toString() ?? '';
      if (gymId.isEmpty || gymId == activeGymId) return;
      activeGymId = gymId;
      listenToRewards(gymId: gymId);
    });
  }

  bool isPremiumRewardType(String type) {
    if (type == 'achievement_unlocked') return true;
    if (type == 'challenge_completed') return true;
    if (type == 'duel_won') return true;
    if (type.startsWith('ranking_') && (type.contains('top1') || type.contains('top3'))) return true;
    return false;
  }

  bool belongsToCurrentUser(Map<String, dynamic> data) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final notificationUserId = data['userId']?.toString() ?? '';
    final notificationEmail = (data['userEmail'] ?? '').toString().toLowerCase();
    final userEmail = (user.email ?? '').toLowerCase();
    return (notificationUserId.isNotEmpty && notificationUserId == user.uid) ||
        (notificationEmail.isNotEmpty && notificationEmail == userEmail);
  }

  void listenToRewards({required String gymId}) {
    rewardSubscription?.cancel();
    rewardSubscription = FirebaseFirestore.instance
        .collection('gyms')
        .doc(gymId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(25)
        .snapshots()
        .listen((snapshot) {
      if (!mounted || showingReward) return;
      for (final doc in snapshot.docs) {
        if (handledIds.contains(doc.id)) continue;
        final data = doc.data();
        final type = data['type']?.toString() ?? '';
        if (!isPremiumRewardType(type)) continue;
        if (!belongsToCurrentUser(data)) continue;
        if (data['rewardShown'] == true) continue;
        if (data['read'] == true) continue;
        handledIds.add(doc.id);
        WidgetsBinding.instance.addPostFrameCallback((_) => showReward(doc));
        break;
      }
    });
  }

  Future<void> showReward(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    if (!mounted || showingReward) return;
    showingReward = true;
    try {
      await doc.reference.set({
        'rewardShown': true,
        'rewardShownAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final reward = PremiumRewardPayload.fromNotification(doc.data());
      if (mounted) {
        await showPremiumRewardDialog(context: context, reward: reward);
      }
    } finally {
      showingReward = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

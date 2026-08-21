import 'subscription_service.dart';

class TrainerPermissionService {
  const TrainerPermissionService();

  bool isGymAdmin(String trainerRole) => trainerRole.trim().toLowerCase() == 'gym_admin';

  bool canUseChat(GymSubscriptionPlan plan) => plan.chatEnabled;
  bool canUseCommunity(GymSubscriptionPlan plan) => plan.communityEnabled;
  bool canUseChallenges(GymSubscriptionPlan plan) => plan.challengesEnabled;
  bool canUseRankings(GymSubscriptionPlan plan) => plan.rankingsEnabled;

  String lockedFeatureReason(
    String featureName,
    GymSubscriptionPlan plan,
  ) {
    if (!plan.isActive) {
      return 'La suscripción del gimnasio no está activa.';
    }
    return '$featureName no está incluido en el plan ${plan.plan}.';
  }
}

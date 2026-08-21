import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import 'subscription_page.dart';

class SubscriptionFeatureGate extends StatelessWidget {
  final String gymId;
  final String featureKey;
  final String featureName;
  final String upgradeReason;
  final Widget child;

  const SubscriptionFeatureGate({
    super.key,
    required this.gymId,
    required this.featureKey,
    required this.featureName,
    required this.upgradeReason,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GymSubscriptionPlan>(
      stream: SubscriptionService(gymId: gymId).watchPlan(),
      builder: (context, snapshot) {
        final plan = snapshot.data ?? GymSubscriptionPlan.fallback(gymId);
        if (!plan.isActive || !plan.hasFeature(featureKey)) {
          return SubscriptionUpgradePage(
            gymId: gymId,
            featureName: featureName,
            reason: !plan.isActive
                ? 'La suscripción del gimnasio no está activa.'
                : upgradeReason,
          );
        }
        return child;
      },
    );
  }
}

class SubscriptionUpgradePage extends StatelessWidget {
  final String gymId;
  final String featureName;
  final String reason;

  const SubscriptionUpgradePage({
    super.key,
    required this.gymId,
    required this.featureName,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(featureName)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: context.gymPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(Icons.workspace_premium_rounded, size: 34, color: context.gymPrimary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$featureName disponible con un plan superior',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.gymText, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.gymMutedText, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SubscriptionPage(gymId: gymId)),
                        );
                      },
                      icon: const Icon(Icons.upgrade_rounded),
                      label: const Text('Ver planes y actualizar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

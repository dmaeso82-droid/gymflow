import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/subscription_service.dart';
import '../widgets/app_card.dart';
import '../widgets/section_title.dart';

class SubscriptionPage extends StatefulWidget {
  final String gymId;
  const SubscriptionPage({super.key, required this.gymId});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  bool checkoutLoading = false;

  SubscriptionService get service => SubscriptionService(gymId: widget.gymId);

  Map<String, dynamic> callableDataAsMap(HttpsCallableResult<dynamic> result) {
    final data = result.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw StateError('La función no ha devuelto una respuesta válida.');
  }

  Future<void> startStripeCheckout(String plan) async {
    setState(() => checkoutLoading = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('createCheckoutSession');
      final result = await callable.call(<String, dynamic>{
        'gymId': widget.gymId,
        'plan': plan,
        'origin': Uri.base.origin,
      });
      final data = callableDataAsMap(result);
      final url = data['url']?.toString() ?? '';
      if (url.isEmpty) throw StateError('Stripe no ha devuelto URL de Checkout.');
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('No se pudo abrir Stripe Checkout.');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo abrir Checkout: $error')));
      }
    } finally {
      if (mounted) setState(() => checkoutLoading = false);
    }
  }

  Stream<int> collectionCount(String name) {
    return FirebaseFirestore.instance
        .collection('gyms')
        .doc(widget.gymId)
        .collection(name)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Widget metricCard({required String title, required Stream<int> stream, required int limit}) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        final value = snapshot.data ?? 0;
        final limitText = limit >= 999999 ? 'Ilimitado' : limit.toString();
        return AppCard(
          child: Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
              Text('$value / $limitText', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        );
      },
    );
  }

  Widget featureRow(String label, bool enabled) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(enabled ? Icons.check_circle : Icons.lock_outline, color: enabled ? Colors.greenAccent : Colors.orangeAccent),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Widget freePlanCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(child: Text('Free', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
              Text('0 €', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('1 cliente, 1 entrenador y comunidad incluida. No requiere tarjeta.'),
          const SizedBox(height: 12),
          const Row(children: [Icon(Icons.check_circle, color: Colors.greenAccent), SizedBox(width: 8), Expanded(child: Text('Incluido automáticamente al crear el gimnasio.'))]),
        ],
      ),
    );
  }

  Widget stripePlanButton({required String plan, required String title, required String price, required String subtitle}) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
              Text(price, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: checkoutLoading ? null : () => startStripeCheckout(plan),
              icon: checkoutLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.payment),
              label: const Text('Elegir plan y pagar con Stripe'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan y suscripción')),
      body: SafeArea(
        child: StreamBuilder<GymSubscriptionPlan>(
          stream: service.watchPlan(),
          builder: (context, snapshot) {
            final plan = snapshot.data ?? GymSubscriptionPlan.fallback(widget.gymId);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(icon: Icons.workspace_premium, title: 'Suscripción actual'),
                      const SizedBox(height: 12),
                      Text('Plan: ${plan.displayPlan}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('Estado: ${plan.displayStatus}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (plan.renewalDate.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Renovación: ${plan.renewalDate}'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                metricCard(title: 'Clientes', stream: collectionCount('clients'), limit: plan.maxClients),
                const SizedBox(height: 12),
                metricCard(title: 'Entrenadores', stream: collectionCount('trainers'), limit: plan.maxTrainers),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(icon: Icons.toggle_on, title: 'Funciones incluidas'),
                      const SizedBox(height: 12),
                      featureRow('Comunidad', plan.communityEnabled),
                      featureRow('Rankings', plan.rankingsEnabled),
                      featureRow('Chat', plan.chatEnabled),
                      featureRow('Retos', plan.challengesEnabled),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(icon: Icons.payments, title: 'Planes disponibles'),
                      const SizedBox(height: 12),
                      const Text('Elige el plan que mejor encaje con tu gimnasio. El cambio se confirmará automáticamente cuando Stripe complete el pago.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                freePlanCard(),
                const SizedBox(height: 12),
                stripePlanButton(plan: 'starter', title: 'Starter', price: '29 €/mes', subtitle: 'Hasta 50 clientes, 2 entrenadores, comunidad y chat incluidos.'),
                const SizedBox(height: 12),
                stripePlanButton(plan: 'pro', title: 'Pro', price: '79 €/mes', subtitle: 'Hasta 500 clientes, 10 entrenadores, chat, rankings y retos.'),
                const SizedBox(height: 12),
                stripePlanButton(plan: 'enterprise', title: 'Enterprise', price: '199 €/mes', subtitle: 'Clientes y entrenadores ilimitados, todas las funciones.'),
              ],
            );
          },
        ),
      ),
    );
  }
}

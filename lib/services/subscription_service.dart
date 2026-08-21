import 'package:cloud_firestore/cloud_firestore.dart';

class GymSubscriptionPlan {
  final String gymId;
  final String plan;
  final String status;
  final int maxClients;
  final int maxTrainers;
  final String billingEmail;
  final String renewalDate;
  final Map<String, bool> features;

  const GymSubscriptionPlan({
    required this.gymId,
    required this.plan,
    required this.status,
    required this.maxClients,
    required this.maxTrainers,
    required this.billingEmail,
    required this.renewalDate,
    required this.features,
  });

  bool get isActive => status == 'active' || status == 'trial';
  bool get isSuspended => status == 'suspended' || status == 'past_due' || status == 'cancelled';
  bool get isEnterprise => plan == 'enterprise';
  bool get isPro => plan == 'pro';
  bool get isStarter => plan == 'starter';
  bool get isFree => plan == 'free';

  bool hasFeature(String key) {
    if (!isActive) return false;
    if (isEnterprise) return true;
    return features[key] == true;
  }

  bool get communityEnabled => hasFeature('community');
  bool get rankingsEnabled => hasFeature('rankings');
  bool get chatEnabled => hasFeature('chat');
  bool get challengesEnabled => hasFeature('challenges');

  String get displayPlan {
    switch (plan) {
      case 'enterprise': return 'Enterprise';
      case 'pro': return 'Pro';
      case 'starter': return 'Starter';
      case 'free':
      default: return 'Free';
    }
  }

  String get displayStatus {
    switch (status) {
      case 'active': return 'Activo';
      case 'trial': return 'Prueba';
      case 'suspended': return 'Suspendido';
      case 'past_due': return 'Pago pendiente';
      case 'cancelled': return 'Cancelado';
      default: return status;
    }
  }

  /// Safe fallback used only while the subscription document is loading or missing.
  /// Commercial limits and feature flags always come from Firestore.
  factory GymSubscriptionPlan.fallback(String gymId) => GymSubscriptionPlan(
        gymId: gymId,
        plan: 'unavailable',
        status: 'unavailable',
        maxClients: 0,
        maxTrainers: 0,
        billingEmail: '',
        renewalDate: '',
        features: const {
          'community': false,
          'rankings': false,
          'chat': false,
          'challenges': false,
        },
      );
  factory GymSubscriptionPlan.fromMap(String gymId, Map<String, dynamic>? data) {
    final fallback = GymSubscriptionPlan.fallback(gymId);
    if (data == null) return fallback;
    return GymSubscriptionPlan(
      gymId: gymId,
      plan: _normalizedText(data['plan'], fallback.plan),
      status: _normalizedText(data['status'], fallback.status),
      maxClients: _nonNegativeIntValue(data['maxClients'], fallback.maxClients),
      maxTrainers: _nonNegativeIntValue(data['maxTrainers'], fallback.maxTrainers),
      billingEmail: data['billingEmail']?.toString().trim().toLowerCase() ?? '',
      renewalDate: _dateText(data['renewalDate']),
      features: {
        'community': data['community'] == true,
        'rankings': data['rankings'] == true,
        'chat': data['chat'] == true,
        'challenges': data['challenges'] == true,
      },
    );
  }
  Map<String, dynamic> toFirestoreMap({String? ownerUid}) => {
    'gymId': gymId,
    'plan': plan,
    'status': status,
    'maxClients': maxClients.toString(),
    'maxTrainers': maxTrainers.toString(),
    'community': communityEnabled,
    'rankings': rankingsEnabled,
    'chat': chatEnabled,
    'challenges': challengesEnabled,
    'billingEmail': billingEmail,
    'renewalDate': renewalDate,
    if (ownerUid != null) 'ownerUid': ownerUid,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static String _normalizedText(dynamic value, String fallback) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static int _nonNegativeIntValue(dynamic value, int fallback) {
    final parsed = _intValue(value, fallback);
    return parsed < 0 ? fallback : parsed;
  }

  static String _dateText(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    return value?.toString().trim() ?? '';
  }

  static int _intValue(dynamic value, int fallback) {
    if (value == null) return fallback;
    try {
      final text = value.toString().trim();
      if (text.isEmpty) return fallback;
      final parsedInt = int.tryParse(text);
      if (parsedInt != null) return parsedInt;
      final parsedDouble = double.tryParse(text.replaceAll(',', '.'));
      if (parsedDouble != null && parsedDouble.isFinite) return parsedDouble.round();
      final numberLike = RegExp(r'-?\d+').firstMatch(text);
      if (numberLike != null) return int.tryParse(numberLike.group(0) ?? '') ?? fallback;
    } catch (_) { return fallback; }
    return fallback;
  }
}

class SubscriptionService {
  final String gymId;
  const SubscriptionService({required this.gymId});

  DocumentReference<Map<String, dynamic>> get subscriptionRef => FirebaseFirestore.instance.collection('subscriptions').doc(gymId);
  DocumentReference<Map<String, dynamic>> get gymRef => FirebaseFirestore.instance.collection('gyms').doc(gymId);
  CollectionReference<Map<String, dynamic>> get auditRef => gymRef.collection('audit_logs');

  Stream<GymSubscriptionPlan> watchPlan() => subscriptionRef.snapshots().map((snapshot) => GymSubscriptionPlan.fromMap(gymId, snapshot.data()));
  Stream<int> watchClientCount() => gymRef.collection('clients').snapshots().map((snapshot) => snapshot.docs.where((doc) => doc.data()['isTrainerClient'] != true).length);
  Stream<int> watchTrainerCount() => gymRef.collection('trainers').where('active', isEqualTo: true).snapshots().map((snapshot) => snapshot.docs.length);

  Future<GymSubscriptionPlan> loadPlan() async {
    final snapshot = await subscriptionRef.get();
    return GymSubscriptionPlan.fromMap(gymId, snapshot.data());
  }

  Future<void> assertActive({String feature = ''}) async {
    final plan = await loadPlan();
    if (!plan.isActive) throw StateError('La suscripción del gimnasio no está activa.');
    if (feature.isNotEmpty && !plan.hasFeature(feature)) throw StateError('Esta función no está incluida en el plan ${plan.plan}.');
  }

  @Deprecated('Los planes solo pueden modificarse desde Cloud Functions/Stripe.')
  Future<void> updateManualPlan({
    required String plan,
    required String status,
    required String actorUid,
    required String actorName,
    required String actorEmail,
  }) async {
    throw UnsupportedError(
      'La actualización manual de planes desde Flutter está deshabilitada.',
    );
  }
  Future<void> writeAudit({required String type, required String actorUid, required String actorName, required String actorEmail, required String target, Map<String, dynamic>? metadata}) async {
    await auditRef.add({'type': type, 'actorUid': actorUid, 'actorName': actorName, 'actorEmail': actorEmail.toLowerCase(), 'target': target, 'metadata': metadata ?? {}, 'createdAt': FieldValue.serverTimestamp()});
  }
}

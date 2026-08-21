const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const Stripe = require("stripe");
const { db, FieldValue, PRICE_BY_PLAN, planLimits, planLimitsForFirestore, normalizeGymId, normalizePlan, callableError, stripeStatusToGymStatus, firstPlanFromSubscription, dateFromUnixSeconds, assertCanManageGym } = require("./shared");
const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");
const stripeWebhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");

async function upsertSubscriptionFromStripe({gymId, plan, status, billingEmail = "", stripeCustomerId = "", stripeSubscriptionId = "", currentPeriodEnd = "", eventType = "stripe_webhook", eventId = ""}) {
  const safeGymId = normalizeGymId(gymId);
  const safePlan = normalizePlan(plan);
  if (!safeGymId || !PRICE_BY_PLAN[safePlan]) {
    console.warn("Webhook Stripe ignorado por gymId o plan no válido", {gymId, plan, eventType, eventId});
    return false;
  }

  const limits = planLimits(safePlan);
  const now = FieldValue.serverTimestamp();
  const gymRef = db.collection("gyms").doc(safeGymId);
  const subRef = db.collection("subscriptions").doc(safeGymId);
  const gymStatus = stripeStatusToGymStatus(status);

  const batch = db.batch();
  batch.set(gymRef, {
    plan: safePlan,
    subscriptionStatus: gymStatus,
    stripeCustomerId,
    stripeSubscriptionId,
    updatedAt: now,
  }, {merge: true});
  batch.set(subRef, {
    gymId: safeGymId,
    plan: safePlan,
    status: gymStatus,
    billingEmail,
    stripeCustomerId,
    stripeSubscriptionId,
    renewalDate: currentPeriodEnd,
    ...planLimitsForFirestore(limits),
    updatedAt: now,
  }, {merge: true});
  batch.set(gymRef.collection("audit_logs").doc(), {
    type: eventType,
    actorUid: "stripe",
    actorName: "Stripe",
    actorEmail: "",
    target: stripeSubscriptionId || safeGymId,
    metadata: {
      eventId,
      plan: safePlan,
      status: gymStatus,
      stripeCustomerId,
      stripeSubscriptionId,
      currentPeriodEnd,
    },
    createdAt: now,
  });
  await batch.commit();
  return true;
}


exports.createCheckoutSession = onCall({secrets: [stripeSecretKey]}, async (request) => {
  try {
    if (!request.auth) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    const gymId = normalizeGymId(request.data?.gymId);
    const plan = normalizePlan(request.data?.plan);
    const origin = String(request.data?.origin || "").trim();
    if (!gymId || !PRICE_BY_PLAN[plan]) throw new HttpsError("invalid-argument", "Plan o gimnasio no válido.");
    let checkoutOrigin;
    try {
      checkoutOrigin = new URL(origin);
    } catch (_) {
      throw new HttpsError("invalid-argument", "Origen no válido.");
    }
    const isLocalhost = ["localhost", "127.0.0.1"].includes(checkoutOrigin.hostname);
    if (checkoutOrigin.protocol !== "https:" && !isLocalhost) {
      throw new HttpsError("invalid-argument", "El origen de Checkout debe usar HTTPS.");
    }
    checkoutOrigin.search = "";
    checkoutOrigin.hash = "";
    const safeOrigin = checkoutOrigin.toString().replace(/\/$/, "");
    const manager = await assertCanManageGym(request.auth.uid, gymId);
    const gymSnap = await db.collection("gyms").doc(gymId).get();
    if (!gymSnap.exists) throw new HttpsError("not-found", "Gimnasio no encontrado.");
    const secretValue = stripeSecretKey.value();
    if (!secretValue) throw new HttpsError("failed-precondition", "STRIPE_SECRET_KEY no está configurada.");
    const stripe = Stripe(secretValue);
    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      payment_method_types: ["card"],
      line_items: [{price: PRICE_BY_PLAN[plan], quantity: 1}],
      customer_email: manager.email || request.auth.token.email || undefined,
      client_reference_id: gymId,
      success_url: `${safeOrigin}?checkout=success&gymId=${encodeURIComponent(gymId)}&plan=${encodeURIComponent(plan)}`,
      cancel_url: `${safeOrigin}?checkout=cancelled&gymId=${encodeURIComponent(gymId)}`,
      metadata: {gymId, plan, uid: request.auth.uid},
      subscription_data: {metadata: {gymId, plan, uid: request.auth.uid}},
    });
    await db.collection("gyms").doc(gymId).collection("audit_logs").add({
      type: "stripe_checkout_created",
      actorUid: request.auth.uid,
      actorName: manager.name || manager.email || "Admin",
      actorEmail: String(manager.email || request.auth.token.email || "").toLowerCase(),
      target: session.id,
      metadata: {plan, priceId: PRICE_BY_PLAN[plan]},
      createdAt: FieldValue.serverTimestamp(),
    });
    return {url: session.url, sessionId: session.id};
  } catch (error) {
    throw callableError(error, "No se pudo crear la sesión de Stripe Checkout.");
  }
});

exports.applyCheckoutPlanTest = onCall(async (request) => {
  try {
    if (process.env.FUNCTIONS_EMULATOR !== "true") {
      throw new HttpsError("failed-precondition", "La aplicación manual de planes solo está disponible en el emulador.");
    }
    if (!request.auth) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    const gymId = normalizeGymId(request.data?.gymId);
    const plan = normalizePlan(request.data?.plan);
    if (!gymId || !PRICE_BY_PLAN[plan]) throw new HttpsError("invalid-argument", "Plan o gimnasio no válido.");
    const manager = await assertCanManageGym(request.auth.uid, gymId);
    const limits = planLimits(plan);
    const now = FieldValue.serverTimestamp();
    const batch = db.batch();
    const gymRef = db.collection("gyms").doc(gymId);
    const subRef = db.collection("subscriptions").doc(gymId);
    batch.set(gymRef, {plan, subscriptionStatus: "active", updatedAt: now}, {merge: true});
    batch.set(subRef, {
      gymId,
      plan,
      status: "active",
      billingEmail: manager.email || request.auth.token.email || "",
      ...planLimitsForFirestore(limits),
      updatedAt: now,
    }, {merge: true});
    batch.set(gymRef.collection("audit_logs").doc(), {
      type: "stripe_plan_applied_test",
      actorUid: request.auth.uid,
      actorName: manager.name || manager.email || "Admin",
      actorEmail: String(manager.email || request.auth.token.email || "").toLowerCase(),
      target: gymId,
      metadata: {plan, maxClients: String(limits.maxClients), maxTrainers: String(limits.maxTrainers)},
      createdAt: now,
    });
    await batch.commit();
    return {ok: true, plan};
  } catch (error) {
    throw callableError(error, "No se pudo aplicar el plan de prueba.");
  }
});

exports.stripeWebhook = onRequest({secrets: [stripeSecretKey, stripeWebhookSecret]}, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const stripe = Stripe(stripeSecretKey.value());
  const signature = req.headers["stripe-signature"];
  let event;

  try {
    event = stripe.webhooks.constructEvent(req.rawBody, signature, stripeWebhookSecret.value());
  } catch (error) {
    console.error("Stripe webhook signature verification failed", error);
    res.status(400).send(`Webhook Error: ${error.message}`);
    return;
  }

  try {
    const eventRef = db.collection("stripe_events").doc(event.id);
    const reserved = await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(eventRef);
      if (existing.exists) return false;
      transaction.create(eventRef, {
        type: event.type,
        status: "processing",
        createdAt: FieldValue.serverTimestamp(),
      });
      return true;
    });
    if (!reserved) {
      res.json({received: true, duplicate: true});
      return;
    }

    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object;
        const gymId = normalizeGymId(session.metadata?.gymId || session.client_reference_id);
        const plan = normalizePlan(session.metadata?.plan);
        const subscriptionId = typeof session.subscription === "string" ? session.subscription : session.subscription?.id || "";
        let subscription = null;
        if (subscriptionId) {
          subscription = await stripe.subscriptions.retrieve(subscriptionId);
        }
        await upsertSubscriptionFromStripe({
          gymId,
          plan: plan || firstPlanFromSubscription(subscription),
          status: subscription?.status || "active",
          billingEmail: session.customer_details?.email || session.customer_email || "",
          stripeCustomerId: typeof session.customer === "string" ? session.customer : session.customer?.id || "",
          stripeSubscriptionId: subscriptionId,
          currentPeriodEnd: dateFromUnixSeconds(subscription?.current_period_end),
          eventType: event.type,
          eventId: event.id,
        });
        break;
      }
      case "customer.subscription.created":
      case "customer.subscription.updated":
      case "customer.subscription.deleted": {
        const subscription = event.data.object;
        const gymId = normalizeGymId(subscription.metadata?.gymId);
        const plan = firstPlanFromSubscription(subscription);
        await upsertSubscriptionFromStripe({
          gymId,
          plan,
          status: subscription.status,
          billingEmail: subscription.customer_email || "",
          stripeCustomerId: typeof subscription.customer === "string" ? subscription.customer : subscription.customer?.id || "",
          stripeSubscriptionId: subscription.id || "",
          currentPeriodEnd: dateFromUnixSeconds(subscription.current_period_end),
          eventType: event.type,
          eventId: event.id,
        });
        break;
      }
      case "invoice.payment_failed": {
        const invoice = event.data.object;
        const subscriptionId = typeof invoice.subscription === "string" ? invoice.subscription : invoice.subscription?.id || "";
        let subscription = null;
        if (subscriptionId) {
          subscription = await stripe.subscriptions.retrieve(subscriptionId);
        }
        const gymId = normalizeGymId(subscription?.metadata?.gymId || invoice.metadata?.gymId);
        const plan = firstPlanFromSubscription(subscription);
        await upsertSubscriptionFromStripe({
          gymId,
          plan,
          status: "past_due",
          billingEmail: invoice.customer_email || "",
          stripeCustomerId: typeof invoice.customer === "string" ? invoice.customer : invoice.customer?.id || "",
          stripeSubscriptionId: subscriptionId,
          currentPeriodEnd: dateFromUnixSeconds(subscription?.current_period_end),
          eventType: event.type,
          eventId: event.id,
        });
        break;
      }
      default:
        console.log(`Stripe webhook ignored: ${event.type}`);
    }

    await db.collection("stripe_events").doc(event.id).set({
      status: "completed",
      completedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    res.json({received: true});
  } catch (error) {
    if (event?.id) {
      await db.collection("stripe_events").doc(event.id).set({
        status: "failed",
        failedAt: FieldValue.serverTimestamp(),
        error: String(error?.message || error),
      }, {merge: true});
    }
    console.error("Stripe webhook processing failed", error);
    res.status(500).send("Stripe webhook processing failed");
  }
});



module.exports = { createCheckoutSession: exports.createCheckoutSession, applyCheckoutPlanTest: exports.applyCheckoutPlanTest, stripeWebhook: exports.stripeWebhook };

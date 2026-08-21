const {HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const db = getFirestore();

const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");
const stripeWebhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");

const PRICE_BY_PLAN = {
  starter: "price_1U6FMxC5LPPMWXGhEuwdGtlN",
  pro: "price_1U6FQWC5LPPMWXGhlS6RFdxi",
  enterprise: "price_1U6FS4C5LPPMWXGheeJtSxZb",
};

function planLimits(plan) {
  if (plan === "enterprise") return {maxClients: 999999, maxTrainers: 999999, community: true, rankings: true, chat: true, challenges: true};
  if (plan === "pro") return {maxClients: 500, maxTrainers: 10, community: true, rankings: true, chat: true, challenges: true};
  if (plan === "starter") return {maxClients: 50, maxTrainers: 2, community: true, rankings: false, chat: true, challenges: false};
  return {maxClients: 1, maxTrainers: 2, community: true, rankings: false, chat: false, challenges: false};
}

function planLimitsForFirestore(limits) {
  return {
    maxClients: String(limits.maxClients),
    maxTrainers: String(limits.maxTrainers),
    community: limits.community === true,
    rankings: limits.rankings === true,
    chat: limits.chat === true,
    challenges: limits.challenges === true,
  };
}

function normalizeGymId(value) {
  return String(value || "").trim();
}

function normalizePlan(value) {
  return String(value || "").trim().toLowerCase();
}

function callableError(error, fallbackMessage) {
  if (error instanceof HttpsError) return error;
  console.error(fallbackMessage, error);
  return new HttpsError("internal", fallbackMessage);
}

function stripeStatusToGymStatus(status) {
  switch (status) {
    case "active":
      return "active";
    case "trialing":
      return "trial";
    case "past_due":
    case "unpaid":
    case "incomplete":
    case "incomplete_expired":
      return "past_due";
    case "canceled":
      return "cancelled";
    default:
      return status || "past_due";
  }
}

function firstPlanFromSubscription(subscription) {
  const item = subscription?.items?.data?.[0];
  const priceId = item?.price?.id || "";
  const match = Object.entries(PRICE_BY_PLAN).find(([, value]) => value === priceId);
  return match ? match[0] : normalizePlan(subscription?.metadata?.plan || "starter");
}

function dateFromUnixSeconds(value) {
  if (!value) return "";
  try {
    return new Date(value * 1000).toISOString();
  } catch (error) {
    return "";
  }
}

async function assertCanManageGym(uid, gymId) {
  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists) throw new HttpsError("permission-denied", "Usuario no encontrado.");
  const user = userSnap.data() || {};
  const userGymId = normalizeGymId(user.gymId || user.tenantId || user.currentGymId);
  if (userGymId !== gymId) throw new HttpsError("permission-denied", "El usuario no pertenece a este gimnasio.");
  const isOwner = user.role === "owner";
  const isGymAdmin = user.trainerRole === "gym_admin";
  if (!isOwner && !isGymAdmin) throw new HttpsError("permission-denied", "Solo el propietario o admin puede gestionar el pago.");
  return user;
}

module.exports = { db, FieldValue, PRICE_BY_PLAN, planLimits, planLimitsForFirestore, normalizeGymId, normalizePlan, callableError, stripeStatusToGymStatus, firstPlanFromSubscription, dateFromUnixSeconds, assertCanManageGym };

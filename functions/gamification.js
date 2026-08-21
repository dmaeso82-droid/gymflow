const {onCall, HttpsError} = require("firebase-functions/v2/https");
const { db, FieldValue, normalizeGymId, callableError } = require("./shared");

function normalizeEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function safePositiveInt(value, field) {
  const number = Number(value);
  if (!Number.isInteger(number) || number <= 0) {
    throw new HttpsError("invalid-argument", `${field} no es valido.`);
  }
  return number;
}

function safeNonNegativeNumber(value, field) {
  const number = Number(value);
  if (!Number.isFinite(number) || number < 0) {
    throw new HttpsError("invalid-argument", `${field} no es valido.`);
  }
  return number;
}
function safeNonNegativeInt(value, field) {
  const number = Number(value);
  if (!Number.isInteger(number) || number < 0) {
    throw new HttpsError("invalid-argument", `${field} no es valido.`);
  }
  return number;
}

async function authenticatedGymUser(request, requestedGymId) {
  if (!request.auth) throw new HttpsError("unauthenticated", "Debes iniciar sesion.");
  const userSnap = await db.collection("users").doc(request.auth.uid).get();
  if (!userSnap.exists) throw new HttpsError("permission-denied", "Usuario no encontrado.");
  const user = userSnap.data() || {};
  const gymId = normalizeGymId(requestedGymId);
  if (!gymId || normalizeGymId(user.gymId) !== gymId || user.active === false) {
    throw new HttpsError("permission-denied", "No perteneces a este gimnasio.");
  }
  return {uid: request.auth.uid, gymId, user};
}

async function assertActiveFeature(gymId, feature = "") {
  const snap = await db.collection("subscriptions").doc(gymId).get();
  if (!snap.exists) throw new HttpsError("failed-precondition", "La suscripcion no existe.");
  const subscription = snap.data() || {};
  if (!["active", "trial"].includes(String(subscription.status || "").trim().toLowerCase())) {
    throw new HttpsError("failed-precondition", "La suscripcion no esta activa.");
  }
  if (feature && String(subscription.plan || "").trim().toLowerCase() !== "enterprise" && subscription[feature] !== true) {
    throw new HttpsError("permission-denied", "La funcion no esta incluida en el plan.");
  }
  return subscription;
}

function periodKeys(date = new Date()) {
  return {
    monthKey: `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`,
    yearKey: String(date.getUTCFullYear()),
  };
}

async function awardPointsServer({gymId, uid, user, points, sourceType, sourceId, metadata = {}}) {
  const cleanType = String(sourceType || "").trim();
  const cleanId = String(sourceId || "").trim();
  if (!cleanType || !cleanId) throw new HttpsError("invalid-argument", "Falta el origen de los puntos.");
  const safePoints = safePositiveInt(points, "points");
  const ledgerId = `${uid}_${cleanType}_${cleanId}`.replace(/[^a-zA-Z0-9_-]+/g, "_");
  const gymRef = db.collection("gyms").doc(gymId);
  const ledgerRef = gymRef.collection("points_ledger").doc(ledgerId);
  const leaderboardRef = gymRef.collection("leaderboard").doc(uid);
  const userStatsRef = gymRef.collection("user_stats").doc(uid);
  const rankingStatsRef = gymRef.collection("ranking_stats").doc(uid);
  const {monthKey, yearKey} = periodKeys();
  return db.runTransaction(async (transaction) => {
    const [ledgerSnap, boardSnap] = await Promise.all([
      transaction.get(ledgerRef),
      transaction.get(leaderboardRef),
    ]);
    if (ledgerSnap.exists) return false;
    const current = boardSnap.data() || {};
    const rawMonthly = Number(current.monthlyPoints || 0);
    const rawYearly = Number(current.yearlyPoints || 0);
    const rawAllTime = Number(current.allTimePoints || 0);
    const monthlyBase = current.monthKey === monthKey && Number.isFinite(rawMonthly) ? rawMonthly : 0;
    const yearlyBase = current.yearKey === yearKey && Number.isFinite(rawYearly) ? rawYearly : 0;
    const allTimeBase = Number.isFinite(rawAllTime) && rawAllTime >= 0 ? rawAllTime : 0;
    const common = {
      userId: uid,
      userName: String(user.name || requestNameFallback(user)),
      userEmail: normalizeEmail(user.email),
      updatedAt: FieldValue.serverTimestamp(),
    };
    transaction.create(ledgerRef, {...common, points: safePoints, sourceType: cleanType, sourceId: cleanId, metadata, createdAt: FieldValue.serverTimestamp()});
    transaction.set(leaderboardRef, {...common, monthKey, yearKey, monthlyPoints: monthlyBase + safePoints, yearlyPoints: yearlyBase + safePoints, allTimePoints: allTimeBase + safePoints, lastPointsSourceType: cleanType, lastPointsSourceId: cleanId}, {merge: true});
    transaction.set(userStatsRef, {...common, points: FieldValue.increment(safePoints), lastPointsSourceType: cleanType, lastPointsSourceId: cleanId}, {merge: true});
    transaction.set(rankingStatsRef, {...common, points: FieldValue.increment(safePoints), lastPointsSourceType: cleanType, lastPointsSourceId: cleanId}, {merge: true});
    return true;
  });
}

function requestNameFallback(user) {
  return user.displayName || user.email || "Usuario";
}

exports.awardPointsSecure = onCall(async (request) => {
  try {
    const identity = await authenticatedGymUser(request, request.data?.gymId);
    await assertActiveFeature(identity.gymId, "rankings");
    const awarded = await awardPointsServer({
      gymId: identity.gymId,
      uid: identity.uid,
      user: identity.user,
      points: request.data?.points,
      sourceType: request.data?.sourceType,
      sourceId: request.data?.sourceId,
      metadata: request.data?.metadata && typeof request.data.metadata === "object" ? request.data.metadata : {},
    });
    return {ok: true, awarded};
  } catch (error) {
    throw callableError(error, "No se pudieron conceder los puntos.");
  }
});

exports.recordWorkoutSetSecure = onCall(async (request) => {
  try {
    const identity = await authenticatedGymUser(request, request.data?.gymId);
    await assertActiveFeature(identity.gymId);
    const routineId = String(request.data?.routineId || "").trim();
    const exerciseId = String(request.data?.exerciseId || "").trim();
    const setNumber = safePositiveInt(request.data?.setNumber, "setNumber");
    const reps = safePositiveInt(request.data?.reps, "reps");
    const weight = safeNonNegativeNumber(request.data?.weight, "weight");
    const plannedSetCount = request.data?.plannedSetCount == null
      ? 0
      : safeNonNegativeInt(request.data.plannedSetCount, "plannedSetCount");
    if (!routineId || !exerciseId) throw new HttpsError("invalid-argument", "Falta rutina o ejercicio.");
    const routineRef = db.collection("gyms").doc(identity.gymId).collection("routines").doc(routineId);
    const logId = `${identity.uid}_${routineId}_${exerciseId}_${setNumber}`.replace(/[^a-zA-Z0-9_-]+/g, "_");
    const logRef = db.collection("gyms").doc(identity.gymId).collection("workout_logs").doc(logId);
    const statsRef = db.collection("gyms").doc(identity.gymId).collection("user_stats").doc(identity.uid);
    const rankingRef = db.collection("gyms").doc(identity.gymId).collection("ranking_stats").doc(identity.uid);
    const result = await db.runTransaction(async (transaction) => {
      const [existing, routineSnap] = await Promise.all([transaction.get(logRef), transaction.get(routineRef)]);
      if (existing.exists) return false;
      if (!routineSnap.exists) throw new HttpsError("not-found", "Rutina no encontrada.");
      const routine = routineSnap.data() || {};
      const ownsRoutine = String(routine.clientId || "") === identity.uid || normalizeEmail(routine.clientEmail) === normalizeEmail(identity.user.email);
      if (!ownsRoutine && identity.user.role !== "trainer" && identity.user.role !== "owner") {
        throw new HttpsError("permission-denied", "La rutina no pertenece al usuario.");
      }
      const volume = weight * reps;
      const common = {userId: identity.uid, userName: String(identity.user.name || requestNameFallback(identity.user)), userEmail: normalizeEmail(identity.user.email), updatedAt: FieldValue.serverTimestamp()};
      transaction.create(logRef, {...common, routineId, routineTitle: String(request.data?.routineTitle || routine.title || "Rutina"), exerciseId, exercise: String(request.data?.exerciseName || "Ejercicio"), weight, reps, setNumber, plannedSetCount, createdAt: FieldValue.serverTimestamp()});
      const increments = {...common, series: FieldValue.increment(1), reps: FieldValue.increment(reps), volume: FieldValue.increment(volume), updatedAt: FieldValue.serverTimestamp()};
      transaction.set(statsRef, increments, {merge: true});
      transaction.set(rankingRef, increments, {merge: true});
      return true;
    });
    return {ok: true, created: result, logId};
  } catch (error) {
    throw callableError(error, "No se pudo registrar la serie.");
  }
});

module.exports = { awardPointsSecure: exports.awardPointsSecure, recordWorkoutSetSecure: exports.recordWorkoutSetSecure };

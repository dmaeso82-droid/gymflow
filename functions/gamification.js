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

const ACHIEVEMENTS = [
  ["first_workout", "Primer entrenamiento", "Completa tu primer entrenamiento.", "workouts", 1, "workout"],
  ["workouts_10", "10 entrenamientos", "Completa 10 entrenamientos.", "workouts", 10, "workout"],
  ["workouts_50", "50 entrenamientos", "Completa 50 entrenamientos.", "workouts", 50, "trophy"],
  ["workouts_100", "100 entrenamientos", "Completa 100 entrenamientos.", "workouts", 100, "trophy"],
  ["series_10", "10 series registradas", "Registra 10 series.", "series", 10, "series"],
  ["series_50", "50 series registradas", "Registra 50 series.", "series", 50, "series"],
  ["series_100", "100 series registradas", "Registra 100 series.", "series", 100, "series"],
  ["volume_10000", "10.000 kg movidos", "Acumula 10.000 kg de volumen.", "volume", 10000, "volume"],
  ["volume_50000", "50.000 kg movidos", "Acumula 50.000 kg de volumen.", "volume", 50000, "volume"],
  ["volume_100000", "100.000 kg movidos", "Acumula 100.000 kg de volumen.", "volume", 100000, "volume"],
  ["streak_7", "Racha de 7 días", "Entrena 7 días de apertura seguidos.", "streak", 7, "streak"],
  ["streak_30", "Racha de 30 días", "Entrena 30 días de apertura seguidos.", "streak", 30, "streak"],
  ["exercises_10", "10 ejercicios diferentes", "Registra 10 ejercicios diferentes.", "exercises", 10, "exercise"],
  ["first_progress_photo", "Primera foto de progreso", "Sube tu primera foto de progreso.", "photos", 1, "photo"],
  ["progress_photos_10", "10 fotos de progreso", "Sube 10 fotos de progreso.", "photos", 10, "photo"],
  ["progress_photos_25", "25 fotos de progreso", "Sube 25 fotos de progreso.", "photos", 25, "photo"],
  ["first_transformation_shared", "Primera transformación compartida", "Comparte tu primera transformación.", "transformations", 1, "transformation"],
  ["transformations_3", "3 transformaciones compartidas", "Comparte 3 transformaciones.", "transformations", 3, "transformation"],
  ["transformations_10", "10 transformaciones compartidas", "Comparte 10 transformaciones.", "transformations", 10, "transformation"],
].map(([id, title, description, metric, target, iconKey]) => ({id, title, description, metric, target, iconKey}));

async function countQuery(query) {
  const snap = await query.count().get();
  return snap.data().count;
}

async function secureUserStats(gymId, uid) {
  const gymRef = db.collection("gyms").doc(gymId);
  const statsSnap = await gymRef.collection("user_stats").doc(uid).get();
  const data = statsSnap.data() || {};
  const [photos, transformations, completedGoals, measurements] = await Promise.all([
    countQuery(gymRef.collection("progress_photos").where("userId", "==", uid)),
    countQuery(gymRef.collection("community_posts").where("type", "==", "transformation_post").where("userId", "==", uid)),
    countQuery(gymRef.collection("goals").where("userId", "==", uid).where("completed", "==", true)),
    countQuery(gymRef.collection("body_measurements").where("userId", "==", uid)),
  ]);
  return {
    workouts: Number(data.workouts || 0), series: Number(data.series || 0),
    volume: Number(data.volume || 0), streak: Number(data.currentStreak || 0),
    exercises: Number(data.exerciseCount || 0), photos, transformations,
    completedGoals, measurements,
  };
}

function achievementValue(stats, metric) {
  return Number(stats[metric] || 0);
}

async function createServerNotification(gymRef, uid, user, type, title, message, sourceId, metadata) {
  await gymRef.collection("notifications").add({
    userId: uid, userEmail: normalizeEmail(user.email), type, title, message,
    sourceId, metadata: metadata || {}, read: false,
    createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
  });
}

exports.evaluateAchievementsSecure = onCall(async (request) => {
  try {
    const identity = await authenticatedGymUser(request, request.data?.gymId);
    await assertActiveFeature(identity.gymId);
    const requested = Array.isArray(request.data?.metrics) ? new Set(request.data.metrics.map(String)) : null;
    const stats = await secureUserStats(identity.gymId, identity.uid);
    const gymRef = db.collection("gyms").doc(identity.gymId);
    const unlocked = [];
    for (const definition of ACHIEVEMENTS) {
      if (requested && !requested.has(definition.metric)) continue;
      const current = achievementValue(stats, definition.metric);
      if (current < definition.target) continue;
      const ref = gymRef.collection("user_achievements").doc(`${identity.uid}_${definition.id}`);
      const created = await db.runTransaction(async (transaction) => {
        if ((await transaction.get(ref)).exists) return false;
        transaction.create(ref, {
          achievementId: definition.id, userId: identity.uid,
          userName: String(identity.user.name || requestNameFallback(identity.user)),
          userEmail: normalizeEmail(identity.user.email), ...definition, current,
          unlockedAt: FieldValue.serverTimestamp(), createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (!created) continue;
      const metadata = {...definition, current};
      await awardPointsServer({gymId: identity.gymId, uid: identity.uid, user: identity.user, points: 25, sourceType: "achievement_unlocked", sourceId: definition.id, metadata});
      await createServerNotification(gymRef, identity.uid, identity.user, "achievement_unlocked", "Logro desbloqueado", `${definition.title} conseguido.`, definition.id, metadata);
      unlocked.push(metadata);
    }
    return {ok: true, unlocked};
  } catch (error) {
    throw callableError(error, "No se pudieron evaluar los logros.");
  }
});

function challengeProgress(type, stats) {
  const values = {volume_total: stats.volume, series_count: stats.series, streak_days: stats.streak, goals_completed: stats.completedGoals, measurements_count: stats.measurements, workout_count: stats.workouts};
  return Number(values[type] || 0);
}

exports.completeChallengesSecure = onCall(async (request) => {
  try {
    const identity = await authenticatedGymUser(request, request.data?.gymId);
    await assertActiveFeature(identity.gymId, "challenges");
    const gymRef = db.collection("gyms").doc(identity.gymId);
    const [stats, challenges] = await Promise.all([secureUserStats(identity.gymId, identity.uid), gymRef.collection("challenges").where("active", "==", true).get()]);
    const completed = [];
    for (const doc of challenges.docs) {
      const challenge = doc.data() || {};
      const target = Number(challenge.target || 0);
      const progress = challengeProgress(String(challenge.type || "workout_count"), stats);
      if (target <= 0 || progress < target) continue;
      const ref = gymRef.collection("challenge_completions").doc(`${identity.uid}_${doc.id}`);
      const created = await db.runTransaction(async (transaction) => {
        if ((await transaction.get(ref)).exists) return false;
        transaction.create(ref, {challengeId: doc.id, challengeTitle: String(challenge.title || "Reto"), challengeType: String(challenge.type || "workout_count"), target, progress, userId: identity.uid, userName: String(identity.user.name || requestNameFallback(identity.user)), userEmail: normalizeEmail(identity.user.email), points: 75, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
        return true;
      });
      if (!created) continue;
      const metadata = {challengeId: doc.id, challengeTitle: String(challenge.title || "Reto"), challengeType: String(challenge.type || "workout_count"), progress, target};
      await awardPointsServer({gymId: identity.gymId, uid: identity.uid, user: identity.user, points: 75, sourceType: "challenge_completed", sourceId: doc.id, metadata});
      await createServerNotification(gymRef, identity.uid, identity.user, "challenge_completed", "Reto completado", `Has completado "${metadata.challengeTitle}" y sumas 75 puntos.`, doc.id, metadata);
      completed.push(metadata);
    }
    return {ok: true, completed};
  } catch (error) {
    throw callableError(error, "No se pudieron completar los retos.");
  }
});

module.exports = {
  awardPointsSecure: exports.awardPointsSecure,
  recordWorkoutSetSecure: exports.recordWorkoutSetSecure,
  evaluateAchievementsSecure: exports.evaluateAchievementsSecure,
  completeChallengesSecure: exports.completeChallengesSecure,
};

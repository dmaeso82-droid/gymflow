const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getAuth} = require("firebase-admin/auth");
const {
  db,
  FieldValue,
  planLimits,
  normalizeGymId,
  callableError,
  assertCanManageGym,
} = require("./shared");

async function assertDocumentBelongsToGym(snapshot, gymId, label = "Documento") {
  if (!snapshot.exists) throw new HttpsError("not-found", `${label} no encontrado.`);
  const data = snapshot.data() || {};
  if (data.gymId && normalizeGymId(data.gymId) !== normalizeGymId(gymId)) {
    throw new HttpsError("permission-denied", `${label} no pertenece a este gimnasio.`);
  }
  return data;
}

function normalizeProvisionEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function validateProvisionData(data) {
  const name = String(data?.name || "").trim();
  const email = normalizeProvisionEmail(data?.email);
  if (name.length < 2 || name.length > 120) {
    throw new HttpsError("invalid-argument", "El nombre no es válido.");
  }
  if (!email || !email.includes("@") || email.length > 254) {
    throw new HttpsError("invalid-argument", "El email no es válido.");
  }
  return {name, email};
}

async function activeSubscriptionWithLimits(gymId) {
  const snapshot = await db.collection("subscriptions").doc(gymId).get();
  if (!snapshot.exists) {
    throw new HttpsError("failed-precondition", "La suscripción no existe.");
  }
  const subscription = snapshot.data() || {};
  if (!["active", "trial"].includes(String(subscription.status || ""))) {
    throw new HttpsError("failed-precondition", "La suscripción del gimnasio no está activa.");
  }
  const defaults = planLimits(String(subscription.plan || "free"));
  const maxClients = Number.parseInt(String(subscription.maxClients || defaults.maxClients), 10);
  const maxTrainers = Number.parseInt(String(subscription.maxTrainers || defaults.maxTrainers), 10);
  return {
    ...subscription,
    maxClients: Number.isFinite(maxClients) ? maxClients : defaults.maxClients,
    maxTrainers: Number.isFinite(maxTrainers) ? maxTrainers : defaults.maxTrainers,
  };
}

async function assertProvisionManager(request, gymId) {
  if (!request.auth) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  const manager = await assertCanManageGym(request.auth.uid, gymId);
  return {uid: request.auth.uid, data: manager};
}

function randomTemporaryPassword() {
  const crypto = require("crypto");
  return `Gf!${crypto.randomBytes(24).toString("base64url")}9a`;
}

async function createAuthUserForGym({name, email}) {
  try {
    return await getAuth().createUser({
      email,
      password: randomTemporaryPassword(),
      displayName: name,
      emailVerified: false,
      disabled: false,
    });
  } catch (error) {
    if (error?.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "Ese email ya existe en Firebase Authentication.");
    }
    throw error;
  }
}

exports.provisionClientSecure = onCall(async (request) => {
  let createdUid = "";
  try {
    const gymId = normalizeGymId(request.data?.gymId);
    const {name, email} = validateProvisionData(request.data);
    const goal = String(request.data?.goal || "").trim() || "Objetivo pendiente";
    if (!gymId) throw new HttpsError("invalid-argument", "Falta el gimnasio.");
    const manager = await assertProvisionManager(request, gymId);
    const subscription = await activeSubscriptionWithLimits(gymId);
    const gymRef = db.collection("gyms").doc(gymId);
    const duplicate = await gymRef.collection("clients").where("email", "==", email).limit(1).get();
    if (!duplicate.empty) throw new HttpsError("already-exists", "Ya existe un cliente con ese email en este gimnasio.");
    const current = await gymRef.collection("clients").count().get();
    if (current.data().count >= subscription.maxClients) {
      throw new HttpsError("resource-exhausted", `El plan permite hasta ${subscription.maxClients} clientes.`);
    }
    const authUser = await createAuthUserForGym({name, email});
    createdUid = authUser.uid;
    const now = FieldValue.serverTimestamp();
    const clientRef = gymRef.collection("clients").doc();
    const actorName = String(manager.data.name || manager.data.email || "Admin");
    const commonAudit = {createdBy: actorName, createdByUid: manager.uid, updatedBy: actorName, updatedByUid: manager.uid, createdAt: now, updatedAt: now};
    const batch = db.batch();
    batch.create(clientRef, {name, email, goal, level: "Nuevo", authUid: createdUid, accountStatus: "invited", gymId, ...commonAudit});
    batch.create(db.collection("users").doc(createdUid), {uid: createdUid, name, email, role: "user", gymId, active: true, createdByTrainer: true, createdBy: actorName, createdByUid: manager.uid, createdAt: now, updatedAt: now});
    batch.create(gymRef.collection("members").doc(createdUid), {authUid: createdUid, name, email, role: "user", active: true, createdBy: actorName, createdByUid: manager.uid, createdAt: now, updatedAt: now});
    batch.create(gymRef.collection("activity").doc(), {type: "client_created", target: name, targetId: clientRef.id, targetEmail: email, user: actorName, userUid: manager.uid, userEmail: normalizeProvisionEmail(manager.data.email), metadata: {goal}, createdAt: now});
    batch.set(gymRef, {updatedAt: now}, {merge: true});
    await batch.commit();
    return {ok: true, uid: createdUid, clientId: clientRef.id, email};
  } catch (error) {
    if (createdUid) {
      try { await getAuth().deleteUser(createdUid); } catch (rollbackError) { console.error("Rollback Auth cliente falló", rollbackError); }
    }
    throw callableError(error, "No se pudo crear el cliente.");
  }
});

exports.provisionTrainerSecure = onCall(async (request) => {
  let createdUid = "";
  try {
    const gymId = normalizeGymId(request.data?.gymId);
    const {name, email} = validateProvisionData(request.data);
    const trainerRole = String(request.data?.trainerRole || "trainer").trim();
    if (!gymId) throw new HttpsError("invalid-argument", "Falta el gimnasio.");
    if (!["trainer", "gym_admin"].includes(trainerRole)) {
      throw new HttpsError("invalid-argument", "El rol de entrenador no es válido.");
    }
    const manager = await assertProvisionManager(request, gymId);
    const subscription = await activeSubscriptionWithLimits(gymId);
    const gymRef = db.collection("gyms").doc(gymId);
    const duplicate = await gymRef.collection("trainers").where("email", "==", email).limit(1).get();
    if (!duplicate.empty) throw new HttpsError("already-exists", "Ya existe un entrenador con ese email en este gimnasio.");
    const current = await gymRef.collection("trainers").where("active", "==", true).count().get();
    if (current.data().count >= subscription.maxTrainers) {
      throw new HttpsError("resource-exhausted", `El plan permite hasta ${subscription.maxTrainers} entrenadores activos.`);
    }
    const authUser = await createAuthUserForGym({name, email});
    createdUid = authUser.uid;
    const now = FieldValue.serverTimestamp();
    const actorName = String(manager.data.name || manager.data.email || "Admin");
    const staff = {authUid: createdUid, name, email, role: "trainer", trainerRole, active: true, createdBy: actorName, createdByUid: manager.uid, createdAt: now, updatedAt: now};
    const batch = db.batch();
    batch.create(db.collection("users").doc(createdUid), {uid: createdUid, ...staff, gymId});
    batch.create(gymRef.collection("trainers").doc(createdUid), staff);
    batch.create(gymRef.collection("members").doc(createdUid), staff);
    batch.create(gymRef.collection("audit_logs").doc(), {type: "trainer_created", actorUid: manager.uid, actorName, actorEmail: normalizeProvisionEmail(manager.data.email), target: createdUid, metadata: {email, trainerRole}, createdAt: now});
    batch.set(gymRef, {updatedAt: now}, {merge: true});
    await batch.commit();
    return {ok: true, uid: createdUid, email};
  } catch (error) {
    if (createdUid) {
      try { await getAuth().deleteUser(createdUid); } catch (rollbackError) { console.error("Rollback Auth entrenador falló", rollbackError); }
    }
    throw callableError(error, "No se pudo crear el entrenador.");
  }
});

async function deleteQueryInBatches(query, counter) {
  let deleted = 0;
  while (true) {
    const snapshot = await query.limit(200).get();
    if (snapshot.empty) break;
    const batch = db.batch();
    for (const doc of snapshot.docs) batch.delete(doc.ref);
    await batch.commit();
    deleted += snapshot.size;
    if (snapshot.size < 200) break;
  }
  counter.count += deleted;
}

async function deleteDocumentIfPresent(ref, counter) {
  const snapshot = await ref.get();
  if (!snapshot.exists) return;
  await ref.delete();
  counter.count += 1;
}

async function removeUserDataFromGym({gymId, uid, email, clientId = ""}) {
  const gymRef = db.collection("gyms").doc(gymId);
  const counter = {count: 0};
  const collections = [
    "workout_logs", "goals", "measurements", "body_measurements",
    "user_achievements", "challenge_completions", "points_ledger",
    "notifications", "community_posts", "ranking_stats", "leaderboard",
    "user_stats", "progress_photo_settings", "routines",
  ];
  const directKeys = new Set([uid, clientId].filter(Boolean));
  for (const key of directKeys) {
    for (const name of ["user_stats", "ranking_stats", "leaderboard", "progress_photo_settings"]) {
      await deleteDocumentIfPresent(gymRef.collection(name).doc(key), counter);
    }
  }
  for (const collectionName of collections) {
    const collection = gymRef.collection(collectionName);
    if (clientId) await deleteQueryInBatches(collection.where("clientId", "==", clientId), counter);
    if (uid) {
      await deleteQueryInBatches(collection.where("userId", "==", uid), counter);
      await deleteQueryInBatches(collection.where("authUid", "==", uid), counter);
    }
    if (email) {
      await deleteQueryInBatches(collection.where("email", "==", email), counter);
      await deleteQueryInBatches(collection.where("userEmail", "==", email), counter);
      await deleteQueryInBatches(collection.where("clientEmail", "==", email), counter);
      await deleteQueryInBatches(collection.where("targetEmail", "==", email), counter);
    }
  }
  if (uid) {
    await deleteDocumentIfPresent(gymRef.collection("members").doc(uid), counter);
    await deleteDocumentIfPresent(db.collection("users").doc(uid), counter);
  }
  return counter.count;
}

exports.deleteClientSecure = onCall(async (request) => {
  try {
    const gymId = normalizeGymId(request.data?.gymId);
    const clientId = String(request.data?.clientId || "").trim();
    if (!gymId || !clientId) throw new HttpsError("invalid-argument", "Falta el gimnasio o el cliente.");
    const manager = await assertProvisionManager(request, gymId);
    const gymRef = db.collection("gyms").doc(gymId);
    const clientRef = gymRef.collection("clients").doc(clientId);
    const clientSnap = await clientRef.get();
    if (!clientSnap.exists) throw new HttpsError("not-found", "Cliente no encontrado.");
    const client = await assertDocumentBelongsToGym(clientSnap, gymId, "Cliente");
    const uid = String(client.authUid || "").trim();
    const email = normalizeProvisionEmail(client.email);
    if (uid && uid === request.auth.uid) throw new HttpsError("failed-precondition", "No puedes eliminar tu propia cuenta.");
    if (uid) {
      const userSnap = await db.collection("users").doc(uid).get();
      const user = userSnap.data() || {};
      if (user.role === "owner" || user.trainerRole === "gym_admin") {
        throw new HttpsError("failed-precondition", "No se puede eliminar una cuenta administradora desde Clientes.");
      }
    }
    const deletedRelatedDocs = await removeUserDataFromGym({gymId, uid, email, clientId});
    await clientRef.delete();
    let authDeleted = false;
    if (uid) {
      try { await getAuth().deleteUser(uid); authDeleted = true; }
      catch (error) { if (error?.code !== "auth/user-not-found") throw error; }
    }
    await gymRef.collection("audit_logs").add({
      type: "client_deleted_secure", actorUid: manager.uid,
      actorName: String(manager.data.name || manager.data.email || "Admin"),
      actorEmail: normalizeProvisionEmail(manager.data.email), target: clientId,
      metadata: {uid, email, deletedRelatedDocs, authDeleted},
      createdAt: FieldValue.serverTimestamp(),
    });
    return {ok: true, deletedRelatedDocs, authDeleted};
  } catch (error) {
    throw callableError(error, "No se pudo eliminar el cliente.");
  }
});

exports.deleteTrainerSecure = onCall(async (request) => {
  try {
    const gymId = normalizeGymId(request.data?.gymId);
    const trainerUid = String(request.data?.trainerUid || "").trim();
    if (!gymId || !trainerUid) throw new HttpsError("invalid-argument", "Falta el gimnasio o el entrenador.");
    if (!request.auth) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    if (trainerUid === request.auth.uid) throw new HttpsError("failed-precondition", "No puedes eliminar tu propia cuenta.");
    const manager = await assertProvisionManager(request, gymId);
    const gymRef = db.collection("gyms").doc(gymId);
    const trainerRef = gymRef.collection("trainers").doc(trainerUid);
    const trainerSnap = await trainerRef.get();
    if (!trainerSnap.exists) throw new HttpsError("not-found", "Entrenador no encontrado.");
    const trainer = await assertDocumentBelongsToGym(trainerSnap, gymId, "Entrenador");
    const userSnap = await db.collection("users").doc(trainerUid).get();
    const user = userSnap.data() || {};
    if (user.role === "owner" || trainer.role === "owner") {
      throw new HttpsError("failed-precondition", "No se puede eliminar al propietario del gimnasio.");
    }
    if (trainer.trainerRole === "gym_admin" && manager.data.role !== "owner") {
      throw new HttpsError("permission-denied", "Solo el propietario puede eliminar a un administrador.");
    }
    const email = normalizeProvisionEmail(trainer.email || user.email);
    const deletedRelatedDocs = await removeUserDataFromGym({gymId, uid: trainerUid, email});
    await trainerRef.delete();
    let authDeleted = false;
    try { await getAuth().deleteUser(trainerUid); authDeleted = true; }
    catch (error) { if (error?.code !== "auth/user-not-found") throw error; }
    await gymRef.collection("audit_logs").add({
      type: "trainer_deleted_secure", actorUid: manager.uid,
      actorName: String(manager.data.name || manager.data.email || "Admin"),
      actorEmail: normalizeProvisionEmail(manager.data.email), target: trainerUid,
      metadata: {email, trainerRole: trainer.trainerRole || "trainer", deletedRelatedDocs, authDeleted},
      createdAt: FieldValue.serverTimestamp(),
    });
    return {ok: true, deletedRelatedDocs, authDeleted};
  } catch (error) {
    throw callableError(error, "No se pudo eliminar el entrenador.");
  }
});



function firestoreTimestampMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  return 0;
}

function inviteRoleLimits(subscription, role) {
  return role === "user" ? subscription.maxClients : subscription.maxTrainers;
}

async function currentMemberCount(gymRef, role) {
  if (role === "user") return (await gymRef.collection("clients").count().get()).data().count;
  return (await gymRef.collection("trainers").where("active", "==", true).count().get()).data().count;
}

exports.createInviteSecure = onCall(async (request) => {
  try {
    const gymId = normalizeGymId(request.data?.gymId);
    const {name, email} = validateProvisionData(request.data);
    const role = String(request.data?.role || "user").trim();
    const trainerRole = String(request.data?.trainerRole || "trainer").trim();
    if (!gymId) throw new HttpsError("invalid-argument", "Falta el gimnasio.");
    if (!["user", "trainer"].includes(role)) throw new HttpsError("invalid-argument", "El rol de la invitación no es válido.");
    if (role === "trainer" && !["trainer", "gym_admin"].includes(trainerRole)) throw new HttpsError("invalid-argument", "El rol de entrenador no es válido.");
    const manager = await assertProvisionManager(request, gymId);
    const subscription = await activeSubscriptionWithLimits(gymId);
    const gymRef = db.collection("gyms").doc(gymId);
    const limit = inviteRoleLimits(subscription, role);
    const current = await currentMemberCount(gymRef, role);
    if (current >= limit) throw new HttpsError("resource-exhausted", `El plan no permite más ${role === "user" ? "clientes" : "entrenadores"}.`);
    const pending = await gymRef.collection("invites").where("email", "==", email).where("status", "==", "pending").limit(1).get();
    if (!pending.empty) throw new HttpsError("already-exists", "Ya existe una invitación pendiente para ese email.");
    const inviteRef = gymRef.collection("invites").doc();
    const now = FieldValue.serverTimestamp();
    const expiresAt = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000);
    const actorName = String(manager.data.name || manager.data.email || "Admin");
    const batch = db.batch();
    batch.create(inviteRef, {gymId, name, email, role, trainerRole: role === "trainer" ? trainerRole : "trainer", status: "pending", createdByUid: manager.uid, createdByName: actorName, createdByEmail: normalizeProvisionEmail(manager.data.email), createdAt: now, updatedAt: now, expiresAt});
    batch.create(gymRef.collection("audit_logs").doc(), {type: "invite_created", actorUid: manager.uid, actorName, actorEmail: normalizeProvisionEmail(manager.data.email), target: inviteRef.id, metadata: {email, role, trainerRole}, createdAt: now});
    await batch.commit();
    return {ok: true, inviteId: inviteRef.id};
  } catch (error) {
    throw callableError(error, "No se pudo crear la invitación.");
  }
});

exports.revokeInviteSecure = onCall(async (request) => {
  try {
    const gymId = normalizeGymId(request.data?.gymId);
    const inviteId = String(request.data?.inviteId || "").trim();
    if (!gymId || !inviteId) throw new HttpsError("invalid-argument", "Falta el gimnasio o la invitación.");
    const manager = await assertProvisionManager(request, gymId);
    const gymRef = db.collection("gyms").doc(gymId);
    const inviteRef = gymRef.collection("invites").doc(inviteId);
    const inviteSnap = await inviteRef.get();
    if (!inviteSnap.exists) throw new HttpsError("not-found", "Invitación no encontrada.");
    const invite = await assertDocumentBelongsToGym(inviteSnap, gymId, "Invitacion");
    if (invite.status !== "pending") throw new HttpsError("failed-precondition", "La invitación ya no está pendiente.");
    const now = FieldValue.serverTimestamp();
    const actorName = String(manager.data.name || manager.data.email || "Admin");
    const batch = db.batch();
    batch.update(inviteRef, {status: "revoked", revokedByUid: manager.uid, revokedByName: actorName, revokedByEmail: normalizeProvisionEmail(manager.data.email), revokedAt: now, updatedAt: now});
    batch.create(gymRef.collection("audit_logs").doc(), {type: "invite_revoked", actorUid: manager.uid, actorName, actorEmail: normalizeProvisionEmail(manager.data.email), target: inviteId, createdAt: now});
    await batch.commit();
    return {ok: true};
  } catch (error) {
    throw callableError(error, "No se pudo revocar la invitación.");
  }
});

exports.markInviteExpiredSecure = onCall(async (request) => {
  try {
    const gymId = normalizeGymId(request.data?.gymId);
    const inviteId = String(request.data?.inviteId || "").trim();
    if (!gymId || !inviteId) throw new HttpsError("invalid-argument", "Falta el gimnasio o la invitación.");
    await assertProvisionManager(request, gymId);
    const inviteRef = db.collection("gyms").doc(gymId).collection("invites").doc(inviteId);
    const snapshot = await inviteRef.get();
    if (!snapshot.exists) throw new HttpsError("not-found", "Invitación no encontrada.");
    const invite = snapshot.data() || {};
    if (invite.status !== "pending" || firestoreTimestampMillis(invite.expiresAt) > Date.now()) return {ok: true, changed: false};
    await inviteRef.update({status: "expired", updatedAt: FieldValue.serverTimestamp()});
    return {ok: true, changed: true};
  } catch (error) {
    throw callableError(error, "No se pudo caducar la invitación.");
  }
});

exports.acceptInviteSecure = onCall(async (request) => {
  try {
    if (!request.auth) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    const gymId = normalizeGymId(request.data?.gymId);
    const inviteId = String(request.data?.inviteId || "").trim();
    const name = String(request.data?.name || "").trim();
    const tokenEmail = normalizeProvisionEmail(request.auth.token.email);
    if (!gymId || !inviteId || name.length < 2) throw new HttpsError("invalid-argument", "Faltan datos de la invitación.");
    const gymRef = db.collection("gyms").doc(gymId);
    const inviteRef = gymRef.collection("invites").doc(inviteId);
    const inviteSnap = await inviteRef.get();
    if (!inviteSnap.exists) throw new HttpsError("not-found", "La invitación no existe.");
    const invite = await assertDocumentBelongsToGym(inviteSnap, gymId, "Invitacion");
    if (invite.status !== "pending") throw new HttpsError("failed-precondition", "La invitación ya no está pendiente.");
    if (firestoreTimestampMillis(invite.expiresAt) <= Date.now()) {
      await inviteRef.update({status: "expired", updatedAt: FieldValue.serverTimestamp()});
      throw new HttpsError("deadline-exceeded", "La invitación ha caducado.");
    }
    if (!tokenEmail || normalizeProvisionEmail(invite.email) !== tokenEmail) throw new HttpsError("permission-denied", "El email no coincide con la invitación.");
    const subscription = await activeSubscriptionWithLimits(gymId);
    const role = String(invite.role || "user");
    const limit = inviteRoleLimits(subscription, role);
    const current = await currentMemberCount(gymRef, role);
    if (current >= limit) throw new HttpsError("resource-exhausted", `El plan no permite más ${role === "user" ? "clientes" : "entrenadores"}.`);
    const uid = request.auth.uid;
    const now = FieldValue.serverTimestamp();
    const trainerRole = String(invite.trainerRole || "trainer");
    const memberData = {authUid: uid, name, email: tokenEmail, role, trainerRole, active: true, inviteId, createdAt: now, updatedAt: now};
    await db.runTransaction(async (transaction) => {
      const fresh = await transaction.get(inviteRef);
      if (!fresh.exists || fresh.data()?.status !== "pending") throw new HttpsError("failed-precondition", "La invitación ya ha sido utilizada.");
      transaction.create(db.collection("users").doc(uid), {uid, name, email: tokenEmail, role, trainerRole, gymId, active: true, acceptedInviteId: inviteId, createdAt: now, updatedAt: now});
      transaction.create(gymRef.collection("members").doc(uid), memberData);
      if (role === "trainer") transaction.create(gymRef.collection("trainers").doc(uid), memberData);
      else transaction.create(gymRef.collection("clients").doc(uid), {...memberData, goal: "Objetivo pendiente", level: "Nuevo", accountStatus: "active"});
      transaction.update(inviteRef, {status: "accepted", acceptedByUid: uid, acceptedAt: now, updatedAt: now});
      transaction.create(gymRef.collection("audit_logs").doc(), {type: "invite_accepted", actorUid: uid, actorName: name, actorEmail: tokenEmail, target: inviteId, metadata: {role, trainerRole}, createdAt: now});
    });
    return {ok: true, role, trainerRole};
  } catch (error) {
    throw callableError(error, "No se pudo aceptar la invitación.");
  }
});



function validateUpdateName(value) {
  const name = String(value || "").trim();
  if (name.length < 2 || name.length > 120) throw new HttpsError("invalid-argument", "El nombre no es válido.");
  return name;
}

exports.updateClientSecure = onCall(async (request) => {
  try {
    const gymId = normalizeGymId(request.data?.gymId);
    const clientId = String(request.data?.clientId || "").trim();
    const name = validateUpdateName(request.data?.name);
    const email = normalizeProvisionEmail(request.data?.email);
    const goal = String(request.data?.goal || "").trim() || "Objetivo pendiente";
    if (!gymId || !clientId || !email || !email.includes("@")) throw new HttpsError("invalid-argument", "Faltan datos válidos del cliente.");
    const manager = await assertProvisionManager(request, gymId);
    const gymRef = db.collection("gyms").doc(gymId);
    const clientRef = gymRef.collection("clients").doc(clientId);
    const snapshot = await clientRef.get();
    if (!snapshot.exists) throw new HttpsError("not-found", "Cliente no encontrado.");
    const client = snapshot.data() || {};
    const uid = String(client.authUid || "").trim();
    if (email !== normalizeProvisionEmail(client.email)) {
      const duplicate = await gymRef.collection("clients").where("email", "==", email).limit(1).get();
      if (duplicate.docs.some((doc) => doc.id !== clientId)) throw new HttpsError("already-exists", "Ya existe otro cliente con ese email.");
      if (uid) await getAuth().updateUser(uid, {email});
    }
    if (uid) await getAuth().updateUser(uid, {displayName: name});
    const now = FieldValue.serverTimestamp();
    const actorName = String(manager.data.name || manager.data.email || "Admin");
    const batch = db.batch();
    batch.update(clientRef, {name, email, goal, updatedBy: actorName, updatedByUid: manager.uid, updatedAt: now});
    if (uid) {
      batch.set(db.collection("users").doc(uid), {name, email, updatedAt: now}, {merge: true});
      batch.set(gymRef.collection("members").doc(uid), {name, email, updatedAt: now}, {merge: true});
    }
    const routines = await gymRef.collection("routines").where("clientId", "==", clientId).get();
    for (const routine of routines.docs) batch.update(routine.ref, {clientName: name, clientEmail: email, updatedBy: actorName, updatedByUid: manager.uid, updatedAt: now});
    batch.create(gymRef.collection("activity").doc(), {type: "client_updated", target: name, targetId: clientId, targetEmail: email, user: actorName, userUid: manager.uid, userEmail: normalizeProvisionEmail(manager.data.email), metadata: {previousName: client.name || "", previousEmail: client.email || ""}, createdAt: now});
    batch.create(gymRef.collection("audit_logs").doc(), {type: "client_updated_secure", actorUid: manager.uid, actorName, actorEmail: normalizeProvisionEmail(manager.data.email), target: clientId, metadata: {uid, previousEmail: client.email || "", email}, createdAt: now});
    await batch.commit();
    return {ok: true};
  } catch (error) {
    throw callableError(error, "No se pudo actualizar el cliente.");
  }
});

exports.updateTrainerSecure = onCall(async (request) => {
  try {
    const gymId = normalizeGymId(request.data?.gymId);
    const trainerUid = String(request.data?.trainerUid || "").trim();
    const name = validateUpdateName(request.data?.name);
    const trainerRole = String(request.data?.trainerRole || "trainer").trim();
    if (!gymId || !trainerUid || !["trainer", "gym_admin"].includes(trainerRole)) throw new HttpsError("invalid-argument", "Datos de entrenador no válidos.");
    const manager = await assertProvisionManager(request, gymId);
    const gymRef = db.collection("gyms").doc(gymId);
    const trainerRef = gymRef.collection("trainers").doc(trainerUid);
    const snapshot = await trainerRef.get();
    if (!snapshot.exists) throw new HttpsError("not-found", "Entrenador no encontrado.");
    const trainer = snapshot.data() || {};
    if (trainer.role === "owner") throw new HttpsError("failed-precondition", "No se puede modificar el rol del propietario.");
    if (trainerRole === "gym_admin" && manager.data.role !== "owner") throw new HttpsError("permission-denied", "Solo el propietario puede nombrar administradores.");
    if (trainer.trainerRole === "gym_admin" && manager.data.role !== "owner") throw new HttpsError("permission-denied", "Solo el propietario puede modificar administradores.");
    await getAuth().updateUser(trainerUid, {displayName: name});
    const now = FieldValue.serverTimestamp();
    const actorName = String(manager.data.name || manager.data.email || "Admin");
    const update = {name, trainerRole, updatedAt: now, updatedBy: actorName, updatedByUid: manager.uid};
    const batch = db.batch();
    batch.update(trainerRef, update);
    batch.set(db.collection("users").doc(trainerUid), update, {merge: true});
    batch.set(gymRef.collection("members").doc(trainerUid), update, {merge: true});
    batch.create(gymRef.collection("audit_logs").doc(), {type: "trainer_updated_secure", actorUid: manager.uid, actorName, actorEmail: normalizeProvisionEmail(manager.data.email), target: trainerUid, metadata: {previousRole: trainer.trainerRole || "trainer", trainerRole}, createdAt: now});
    await batch.commit();
    return {ok: true};
  } catch (error) {
    throw callableError(error, "No se pudo actualizar el entrenador.");
  }
});

exports.toggleTrainerStatusSecure = onCall(async (request) => {
  try {
    if (!request.auth) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    const gymId = normalizeGymId(request.data?.gymId);
    const trainerUid = String(request.data?.trainerUid || "").trim();
    const active = request.data?.active === true;
    if (!gymId || !trainerUid) throw new HttpsError("invalid-argument", "Falta el gimnasio o entrenador.");
    if (trainerUid === request.auth.uid) throw new HttpsError("failed-precondition", "No puedes cambiar el estado de tu propia cuenta.");
    const manager = await assertProvisionManager(request, gymId);
    const gymRef = db.collection("gyms").doc(gymId);
    const trainerRef = gymRef.collection("trainers").doc(trainerUid);
    const snapshot = await trainerRef.get();
    if (!snapshot.exists) throw new HttpsError("not-found", "Entrenador no encontrado.");
    const trainer = snapshot.data() || {};
    if (trainer.role === "owner") throw new HttpsError("failed-precondition", "No se puede desactivar al propietario.");
    if (trainer.trainerRole === "gym_admin" && manager.data.role !== "owner") throw new HttpsError("permission-denied", "Solo el propietario puede cambiar el estado de un administrador.");
    if (active) {
      const subscription = await activeSubscriptionWithLimits(gymId);
      const count = await gymRef.collection("trainers").where("active", "==", true).count().get();
      if (count.data().count >= subscription.maxTrainers) throw new HttpsError("resource-exhausted", "El plan no permite activar más entrenadores.");
    }
    const now = FieldValue.serverTimestamp();
    const batch = db.batch();
    batch.update(trainerRef, {active, updatedAt: now});
    batch.set(db.collection("users").doc(trainerUid), {active, updatedAt: now}, {merge: true});
    batch.set(gymRef.collection("members").doc(trainerUid), {active, updatedAt: now}, {merge: true});
    batch.create(gymRef.collection("audit_logs").doc(), {type: active ? "trainer_activated_secure" : "trainer_deactivated_secure", actorUid: manager.uid, actorName: String(manager.data.name || manager.data.email || "Admin"), actorEmail: normalizeProvisionEmail(manager.data.email), target: trainerUid, createdAt: now});
    await batch.commit();
    await getAuth().updateUser(trainerUid, {disabled: !active});
    return {ok: true, active};
  } catch (error) {
    throw callableError(error, "No se pudo cambiar el estado del entrenador.");
  }
});

module.exports = {
  provisionClientSecure: exports.provisionClientSecure,
  provisionTrainerSecure: exports.provisionTrainerSecure,
  deleteClientSecure: exports.deleteClientSecure,
  deleteTrainerSecure: exports.deleteTrainerSecure,
  createInviteSecure: exports.createInviteSecure,
  revokeInviteSecure: exports.revokeInviteSecure,
  markInviteExpiredSecure: exports.markInviteExpiredSecure,
  acceptInviteSecure: exports.acceptInviteSecure,
  updateClientSecure: exports.updateClientSecure,
  updateTrainerSecure: exports.updateTrainerSecure,
  toggleTrainerStatusSecure: exports.toggleTrainerStatusSecure
};

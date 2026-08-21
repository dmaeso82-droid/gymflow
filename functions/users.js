const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getAuth} = require("firebase-admin/auth");
const { db, FieldValue, planLimits, planLimitsForFirestore, normalizeGymId, callableError, assertCanManageGym } = require("./shared");

exports.deleteClientAuthAccount = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    const gymId = normalizeGymId(request.data?.gymId);
    const clientId = String(request.data?.clientId || "").trim();
    const authUid = String(request.data?.authUid || "").trim();
    if (!gymId || !clientId || !authUid) {
      throw new HttpsError("invalid-argument", "Faltan datos del cliente.");
    }
    if (authUid === request.auth.uid) {
      throw new HttpsError("failed-precondition", "No puedes eliminar tu propia cuenta desde Clientes.");
    }
    const manager = await assertCanManageGym(request.auth.uid, gymId);
    const clientRef = db.collection("gyms").doc(gymId).collection("clients").doc(clientId);
    const clientSnap = await clientRef.get();
    if (!clientSnap.exists) {
      throw new HttpsError("not-found", "Cliente no encontrado.");
    }
    const client = clientSnap.data() || {};
    if (String(client.authUid || "").trim() !== authUid) {
      throw new HttpsError("permission-denied", "La cuenta no corresponde al cliente indicado.");
    }
    const userSnap = await db.collection("users").doc(authUid).get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "Perfil de usuario no encontrado.");
    }
    const userData = userSnap.data() || {};
    if (normalizeGymId(userData.gymId) !== gymId) {
      throw new HttpsError("permission-denied", "El usuario no pertenece al gimnasio indicado.");
    }
    const userRole = String(userData.role || "").trim().toLowerCase();
    const trainerRole = String(userData.trainerRole || "").trim().toLowerCase();
    if (userRole === "owner" || trainerRole === "gym_admin") {
      throw new HttpsError("failed-precondition", "No se puede eliminar una cuenta administradora desde Clientes.");
    }
    let authDeleted = true;
    try {
      await getAuth().deleteUser(authUid);
    } catch (error) {
      if (error?.code === "auth/user-not-found") {
        authDeleted = false;
      } else {
        throw error;
      }
    }
    await db.collection("gyms").doc(gymId).collection("audit_logs").add({
      type: "client_auth_deleted",
      actorUid: request.auth.uid,
      actorName: manager.name || manager.email || "Admin",
      actorEmail: String(manager.email || request.auth.token.email || "").toLowerCase(),
      target: authUid,
      metadata: {clientId, authDeleted},
      createdAt: FieldValue.serverTimestamp(),
    });
    return {ok: true, authDeleted};
  } catch (error) {
    throw callableError(error, "No se pudo eliminar la cuenta de Firebase Authentication.");
  }
});


function slugFromGymName(value) {
  const normalized = String(value || "")
      .trim()
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "");
  return normalized || "gymflow-gym";
}

async function availableGymId(baseSlug) {
  let candidate = baseSlug;
  let index = 1;
  while ((await db.collection("gyms").doc(candidate).get()).exists) {
    index += 1;
    candidate = `${baseSlug}-${index}`;
  }
  return candidate;
}

exports.provisionFreeGym = onCall(async (request) => {
  try {
    if (!request.auth) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    const uid = request.auth.uid;
    const ownerName = String(request.data?.ownerName || "").trim();
    const gymName = String(request.data?.gymName || "").trim();
    const phone = String(request.data?.phone || "").trim();
    const address = String(request.data?.address || "").trim();
    const email = String(request.auth.token.email || request.data?.email || "").trim().toLowerCase();
    if (!ownerName || !gymName || !email) {
      throw new HttpsError("invalid-argument", "Faltan nombre, gimnasio o email.");
    }

    const existingUser = await db.collection("users").doc(uid).get();
    if (existingUser.exists) {
      const existingGymId = normalizeGymId(existingUser.data()?.gymId);
      if (existingGymId) return {ok: true, gymId: existingGymId, alreadyProvisioned: true};
      throw new HttpsError("already-exists", "La cuenta ya tiene un perfil sin gimnasio válido.");
    }

    const gymId = await availableGymId(slugFromGymName(gymName));
    const gymRef = db.collection("gyms").doc(gymId);
    const userRef = db.collection("users").doc(uid);
    const subscriptionRef = db.collection("subscriptions").doc(gymId);
    const now = FieldValue.serverTimestamp();
    const limits = planLimits("free");
    const staffData = {
      authUid: uid,
      name: ownerName,
      email,
      role: "owner",
      trainerRole: "gym_admin",
      active: true,
      createdAt: now,
      updatedAt: now,
    };

    const batch = db.batch();
    batch.create(gymRef, {
      name: gymName,
      ownerUid: uid,
      ownerEmail: email,
      ownerName,
      phone,
      address,
      plan: "free",
      subscriptionStatus: "active",
      status: "active",
      createdAt: now,
      updatedAt: now,
    });
    batch.create(userRef, {
      uid,
      name: ownerName,
      email,
      role: "owner",
      trainerRole: "gym_admin",
      gymId,
      active: true,
      createdAt: now,
      updatedAt: now,
    });
    batch.create(gymRef.collection("trainers").doc(uid), staffData);
    batch.create(gymRef.collection("members").doc(uid), staffData);
    batch.create(subscriptionRef, {
      gymId,
      plan: "free",
      status: "active",
      billingEmail: email,
      renewalDate: "",
      ownerUid: uid,
      ...planLimitsForFirestore(limits),
      createdAt: now,
      updatedAt: now,
    });
    batch.create(gymRef.collection("audit_logs").doc(), {
      type: "gym_created_self_service",
      actorUid: uid,
      actorName: ownerName,
      actorEmail: email,
      target: gymId,
      metadata: {plan: "free", status: "active", source: "free_tier"},
      createdAt: now,
    });
    await batch.commit();
    return {ok: true, gymId};
  } catch (error) {
    throw callableError(error, "No se pudo completar la creación del gimnasio.");
  }
});


module.exports = { deleteClientAuthAccount: exports.deleteClientAuthAccount, provisionFreeGym: exports.provisionFreeGym };

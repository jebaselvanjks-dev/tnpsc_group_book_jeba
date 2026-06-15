const functions = require("firebase-functions");
const admin = require("firebase-admin");
const bcrypt = require("bcryptjs");
const nodemailer = require("nodemailer");

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function isValidEmail(email) {
  return typeof email === "string" && EMAIL_REGEX.test(email.trim().toLowerCase());
}

function normalizeEmail(email) {
  return email.trim().toLowerCase();
}

function getMailer() {
  const user = process.env.GMAIL_USER || functions.config().gmail?.user;
  const pass = process.env.GMAIL_APP_PASSWORD || functions.config().gmail?.password;
  if (!user || !pass) return null;
  return nodemailer.createTransport({
    service: "gmail",
    auth: { user, pass },
  });
}

async function sendPasswordEmail(to, password) {
  const transporter = getMailer();
  if (!transporter) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "EMAIL_NOT_CONFIGURED",
    );
  }
  const from = process.env.GMAIL_USER || functions.config().gmail?.user;
  await transporter.sendMail({
    from: `TNPSC Master <${from}>`,
    to,
    subject: "Your TNPSC Master password",
    text:
      `Your password for TNPSC Master is: ${password}\n\n` +
      "Please sign in and change your password from Settings if you want.\n\n" +
      "If you did not request this, contact support.",
    html:
      `<p>Your password for <b>TNPSC Master</b> is:</p>` +
      `<p style="font-size:20px;font-weight:bold">${password}</p>` +
      `<p>Sign in and use <b>Change Password</b> in Settings to set a new one.</p>`,
  });
}

async function findAuthDocByEmail(email) {
  const snap = await db
    .collection("auth_users")
    .where("email", "==", email)
    .limit(1)
    .get();
  if (snap.empty) return null;
  return snap.docs[0];
}

async function findUserDocByEmail(email) {
  const snap = await db
    .collection("users")
    .where("email", "==", email)
    .limit(1)
    .get();
  if (snap.empty) return null;
  return snap.docs[0];
}

/**
 * Register / login — save email + hashed password in API (Firestore auth_users).
 */
exports.saveUserAuth = functions.https.onCall(async (data) => {
  const email = normalizeEmail(data.email || "");
  const password = data.password || "";
  const name = (data.name || "").trim();
  const uid = data.uid || "";
  const action = data.action || "login";

  if (!isValidEmail(email)) {
    throw new functions.https.HttpsError("invalid-argument", "INVALID_EMAIL");
  }
  if (!password || password.length < 6) {
    throw new functions.https.HttpsError("invalid-argument", "WEAK_PASSWORD");
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const existing = await findAuthDocByEmail(email);

  const payload = {
    email,
    passwordHash,
    name: name || existing?.data()?.name || "",
    uid: uid || existing?.data()?.uid || "",
    lastAction: action,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (existing) {
    await existing.ref.update(payload);
  } else {
    await db.collection("auth_users").add({
      ...payload,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  if (uid) {
    await db.collection("users").doc(uid).set(
      { email, name: payload.name, authSyncedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true },
    );
  }

  return { success: true, message: "Password saved to API" };
});

/**
 * Forgot password — email must exist in API; sends password by email.
 */
exports.forgotPassword = functions.https.onCall(async (data) => {
  const email = normalizeEmail(data.email || "");

  if (!email) {
    throw new functions.https.HttpsError("invalid-argument", "INVALID_EMAIL");
  }
  if (!isValidEmail(email)) {
    throw new functions.https.HttpsError("invalid-argument", "INVALID_EMAIL");
  }

  let authDoc = await findAuthDocByEmail(email);
  const userDoc = await findUserDocByEmail(email);

  let firebaseUserExists = false;
  try {
    await auth.getUserByEmail(email);
    firebaseUserExists = true;
  } catch (e) {
    if (e.code !== "auth/user-not-found") {
      console.warn("getUserByEmail:", e.message);
    }
  }

  if (!authDoc && !userDoc && !firebaseUserExists) {
    throw new functions.https.HttpsError("not-found", "EMAIL_NOT_REGISTERED");
  }

  const tempPassword =
    Math.random().toString(36).slice(-4) +
    Math.floor(1000 + Math.random() * 9000).toString();

  const passwordHash = await bcrypt.hash(tempPassword, 10);

  if (authDoc) {
    await authDoc.ref.update({
      passwordHash,
      mustChangePassword: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else {
    await db.collection("auth_users").add({
      email,
      passwordHash,
      uid: userDoc.id,
      name: userDoc.data().name || "",
      mustChangePassword: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  try {
    const userRecord = await auth.getUserByEmail(email);
    await auth.updateUser(userRecord.uid, { password: tempPassword });
  } catch (e) {
    if (e.code !== "auth/user-not-found") {
      console.warn("Firebase Auth update skipped:", e.message);
    }
  }

  await sendPasswordEmail(email, tempPassword);

  return { success: true, message: "PASSWORD_EMAIL_SENT" };
});

/**
 * Change password — requires signed-in user.
 */
exports.changePassword = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "NOT_SIGNED_IN");
  }

  const currentPassword = data.currentPassword || "";
  const newPassword = data.newPassword || "";
  const email = normalizeEmail(data.email || context.auth.token.email || "");

  if (!isValidEmail(email)) {
    throw new functions.https.HttpsError("invalid-argument", "INVALID_EMAIL");
  }
  if (!currentPassword || !newPassword) {
    throw new functions.https.HttpsError("invalid-argument", "MISSING_FIELDS");
  }
  if (newPassword.length < 6) {
    throw new functions.https.HttpsError("invalid-argument", "WEAK_PASSWORD");
  }
  if (currentPassword === newPassword) {
    throw new functions.https.HttpsError("invalid-argument", "SAME_AS_OLD_PASSWORD");
  }

  let authDoc = await findAuthDocByEmail(email);
  const newHash = await bcrypt.hash(newPassword, 10);

  if (!authDoc) {
    await db.collection("auth_users").add({
      email,
      passwordHash: newHash,
      uid: context.auth.uid,
      name: context.auth.token.name || "",
      mustChangePassword: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else {
    const storedHash = authDoc.data().passwordHash;
    const match = await bcrypt.compare(currentPassword, storedHash);
    if (!match) {
      throw new functions.https.HttpsError("permission-denied", "WRONG_CURRENT_PASSWORD");
    }
    await authDoc.ref.update({
      passwordHash: newHash,
      mustChangePassword: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await auth.updateUser(context.auth.uid, { password: newPassword });

  return { success: true, message: "PASSWORD_CHANGED" };
});


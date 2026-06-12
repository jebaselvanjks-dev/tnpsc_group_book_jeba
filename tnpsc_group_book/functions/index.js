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
    from: `TNPSC Study Hub <${from}>`,
    to,
    subject: "Your TNPSC Study Hub password",
    text:
      `Your password for TNPSC Study Hub is: ${password}\n\n` +
      "Please sign in and change your password from Settings if you want.\n\n" +
      "If you did not request this, contact support.",
    html:
      `<p>Your password for <b>TNPSC Study Hub</b> is:</p>` +
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

/**
 * Daily cleanup: remove premium + payment fields for users expired before today.
 * Requires Blaze plan + Cloud Scheduler (enabled on deploy).
 */
exports.cleanupExpiredPremium = functions.pubsub
  .schedule("0 2 * * *")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const now = new Date();
    const startOfToday = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate(),
    );
    const cutoffIso = startOfToday.toISOString();

    const snap = await db
      .collection("users")
      .where("isPremium", "==", true)
      .where("premiumExpiry", "<", cutoffIso)
      .get();

    const batch = db.batch();
    let count = 0;
    snap.docs.forEach((doc) => {
      batch.update(doc.ref, {
        isPremium: false,
        premiumPlan: admin.firestore.FieldValue.delete(),
        premiumExpiry: admin.firestore.FieldValue.delete(),
        lastPaymentAt: admin.firestore.FieldValue.delete(),
        lastPaymentId: admin.firestore.FieldValue.delete(),
        lastOrderId: admin.firestore.FieldValue.delete(),
        premiumClearedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      count++;
    });

    if (count > 0) await batch.commit();
    console.log(`cleanupExpiredPremium: cleared ${count} users before ${cutoffIso}`);
    return null;
  });

/**
 * Verify Razorpay payment and activate premium subscription securely.
 */
exports.verifyRazorpayPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "NOT_SIGNED_IN");
  }

  const paymentId = data.paymentId || "";
  const orderId = data.orderId || "";
  const signature = data.signature || "";
  const planName = data.planName || "Starter";

  if (!paymentId) {
    throw new functions.https.HttpsError("invalid-argument", "MISSING_PAYMENT_ID");
  }

  const uid = context.auth.uid;
  let isValid = false;

  const keyId = process.env.RAZORPAY_KEY_ID || functions.config().razorpay?.key;
  const keySecret = process.env.RAZORPAY_KEY_SECRET || functions.config().razorpay?.secret;

  if (keyId && keySecret) {
    try {
      const Razorpay = require("razorpay");
      const instance = new Razorpay({ key_id: keyId, key_secret: keySecret });

      if (signature && orderId) {
        const crypto = require("crypto");
        const generatedSignature = crypto
          .createHmac("sha256", keySecret)
          .update(orderId + "|" + paymentId)
          .digest("hex");

        isValid = (generatedSignature === signature);
      } else {
        const payment = await instance.payments.fetch(paymentId);
        isValid = (payment && (payment.status === "captured" || payment.status === "authorized"));
      }
    } catch (e) {
      console.error("Razorpay verification failed: ", e.message);
    }
  } else {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "RAZORPAY_NOT_CONFIGURED",
    );
  }

  if (!isValid) {
    throw new functions.https.HttpsError("permission-denied", "PAYMENT_VERIFICATION_FAILED");
  }

  let durationDays = 30;
  if (planName === "Elite") {
    durationDays = 90;
  }

  const expiryDate = new Date();
  expiryDate.setDate(expiryDate.getDate() + durationDays);
  const expiryIso = expiryDate.toISOString();

  const update = {
    isPremium: true,
    premiumPlan: planName,
    premiumExpiry: expiryIso,
    lastPaymentAt: admin.firestore.FieldValue.serverTimestamp(),
    lastPaymentId: paymentId,
  };
  if (orderId) {
    update.lastOrderId = orderId;
  }

  await db.collection("users").doc(uid).set(update, { merge: true });

  return {
    success: true,
    isPremium: true,
    premiumPlan: planName,
    premiumExpiry: expiryIso,
  };
});


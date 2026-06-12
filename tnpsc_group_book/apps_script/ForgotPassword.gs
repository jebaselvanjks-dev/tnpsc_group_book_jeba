/**
 * TNPSC Study Hub – Forgot password email (works without Firebase Blaze plan)
 *
 * SETUP (one time):
 * 1. Firebase Console → Project Settings → Service accounts → Generate new private key (JSON)
 * 2. script.google.com → New project → paste this file
 * 3. Project Settings → Script properties → Add:
 *      SERVICE_ACCOUNT_JSON = entire JSON file content (one line is OK)
 *      GMAIL_SENDER = your Gmail (optional; defaults to your Google account)
 * 4. Run → testForgotPassword once → Allow Gmail + permissions
 * 5. Deploy → New deployment → Web app → Execute as: Me → Anyone can access
 * 6. Copy Web App URL → lib/config/password_email_config.dart → appsScriptWebAppUrl
 */

var FIREBASE_PROJECT_ID = "tnpsc-prepare-app-koilra-c9998";

function doPost(e) {
  try {
    var data = JSON.parse(e.postData.contents);
    var email = (data.email || "").trim().toLowerCase();
    var action = data.action || "forgot";

    if (!email || email.indexOf("@") < 1) {
      return jsonOut({ success: false, error: "INVALID_EMAIL" });
    }

    if (action === "syncPassword") {
      var pwd = data.password || "";
      if (!pwd) return jsonOut({ success: false, error: "MISSING_PASSWORD" });
      updateUserPasswordAdmin(email, pwd);
      return jsonOut({ success: true });
    }

    if (action === "sendOtp") {
      var otp = data.otp || "";
      if (!otp) return jsonOut({ success: false, error: "MISSING_OTP" });
      sendOtpGmail(email, otp);
      return jsonOut({ success: true, message: "OTP_SENT" });
    }

    var tempPassword = generateTempPassword();
    updateUserPasswordAdmin(email, tempPassword);
    sendGmail(email, tempPassword);
    return jsonOut({ success: true, message: "PASSWORD_EMAIL_SENT" });
  } catch (err) {
    return jsonOut({ success: false, error: String(err.message || err) });
  }
}

function doGet() {
  return ContentService.createTextOutput(
    "TNPSC forgot-password API is running. Use POST with JSON body."
  );
}

function testForgotPassword() {
  var email = "your-test@gmail.com"; // change for manual test
  var temp = generateTempPassword();
  updateUserPasswordAdmin(email, temp);
  sendGmail(email, temp);
  Logger.log("Test password sent: " + temp);
}

function generateTempPassword() {
  var chars = "abcdefghjkmnpqrstuvwxyz";
  var s = "";
  for (var i = 0; i < 4; i++) {
    s += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return s + (1000 + Math.floor(Math.random() * 9000));
}

function getServiceAccount() {
  var json = PropertiesService.getScriptProperties().getProperty("SERVICE_ACCOUNT_JSON");
  if (!json) {
    throw new Error("Add SERVICE_ACCOUNT_JSON to Script properties (Firebase service account key)");
  }
  return JSON.parse(json);
}

function getAccessToken() {
  var sa = getServiceAccount();
  var now = Math.floor(Date.now() / 1000);
  var claimSet = {
    iss: sa.client_email,
    sub: sa.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/firebase.database",
  };
  var header = { alg: "RS256", typ: "JWT" };
  var toSign =
    Utilities.base64EncodeWebSafe(JSON.stringify(header)) +
    "." +
    Utilities.base64EncodeWebSafe(JSON.stringify(claimSet));
  var signatureBytes = Utilities.computeRsaSha256Signature(toSign, sa.private_key);
  var signature = Utilities.base64EncodeWebSafe(signatureBytes);
  var jwt = toSign + "." + signature;

  var resp = UrlFetchApp.fetch("https://oauth2.googleapis.com/token", {
    method: "post",
    payload: {
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    },
    muteHttpExceptions: true,
  });
  var body = JSON.parse(resp.getContentText());
  if (!body.access_token) {
    throw new Error(body.error_description || "OAuth token failed");
  }
  return body.access_token;
}

function updateUserPasswordAdmin(email, newPassword) {
  var token = getAccessToken();

  var lookupResp = UrlFetchApp.fetch(
    "https://identitytoolkit.googleapis.com/v1/projects/" +
      FIREBASE_PROJECT_ID +
      "/accounts:lookup",
    {
      method: "post",
      contentType: "application/json",
      headers: { Authorization: "Bearer " + token },
      payload: JSON.stringify({ email: [email] }),
      muteHttpExceptions: true,
    }
  );
  var lookupJson = JSON.parse(lookupResp.getContentText());
  if (!lookupJson.users || !lookupJson.users.length) {
    throw new Error("EMAIL_NOT_REGISTERED");
  }
  var localId = lookupJson.users[0].localId;

  var updateResp = UrlFetchApp.fetch(
    "https://identitytoolkit.googleapis.com/v1/projects/" +
      FIREBASE_PROJECT_ID +
      "/accounts:update",
    {
      method: "post",
      contentType: "application/json",
      headers: { Authorization: "Bearer " + token },
      payload: JSON.stringify({
        localId: localId,
        password: newPassword,
        returnSecureToken: false,
      }),
      muteHttpExceptions: true,
    }
  );
  var updateJson = JSON.parse(updateResp.getContentText());
  if (updateJson.error) {
    throw new Error(updateJson.error.message || "Password update failed");
  }
}

function sendGmail(to, password) {
  var sender =
    PropertiesService.getScriptProperties().getProperty("GMAIL_SENDER") ||
    Session.getActiveUser().getEmail();
  GmailApp.sendEmail(
    to,
    "Your TNPSC Study Hub password",
    "Your password for TNPSC Study Hub is: " +
      password +
      "\n\n1. Open the app and Sign In with this password\n" +
      "2. You will be asked to set a new password\n\n" +
      "If you did not request this, ignore this email.",
    {
      htmlBody:
        "<p>Your password for <b>TNPSC Study Hub</b> is:</p>" +
        "<p style='font-size:22px;font-weight:bold'>" +
        password +
        "</p>" +
        "<p>1. <b>Sign In</b> with this password<br/>" +
        "2. Set a <b>new password</b> in the app</p>",
      name: "TNPSC Study Hub",
      // from: sender,
    }
  );
}

function sendOtpGmail(to, otp) {
  var sender =
    PropertiesService.getScriptProperties().getProperty("GMAIL_SENDER") ||
    Session.getActiveUser().getEmail();
  GmailApp.sendEmail(
    to,
    "Your TNPSC Study Hub OTP",
    "Your OTP for TNPSC Study Hub is: " + otp + "\n\nUse this code to login to your account.",
    {
      htmlBody:
        "<p>Your OTP for <b>TNPSC Study Hub</b> is:</p>" +
        "<p style='font-size:26px;font-weight:bold;color:#1a73e8;letter-spacing:4px;'>" +
        otp +
        "</p>" +
        "<p>Use this code to securely login to your account. This code is valid for your current session.</p>",
      name: "TNPSC Study Hub",
      // from: sender,
    }
  );
}

function jsonOut(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(
    ContentService.MimeType.JSON
  );
}

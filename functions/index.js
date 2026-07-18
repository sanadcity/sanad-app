const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();
setGlobalOptions({ region: "us-central1", maxInstances: 10 });

const HF_KEY = defineSecret("HF_KEY");
const HF_BASE_URL = "https://platform.higgsfield.ai";

// Known-good default from the official SDK docs. Add more slugs here once
// verified in the Higgsfield Cloud dashboard (cloud.higgsfield.ai).
const DEFAULT_APPLICATION = "bytedance/seedream/v4/text-to-image";

// Any registered user with one of these roles may call the ad-content tools.
// This mirrors the app's existing (client-trust) role model — it is not
// Firebase Auth, just a lookup against the same Firestore-backed user list
// the front-end already uses. See README note about hardening this later.
const ALLOWED_ROLES = new Set(["admin", "staff"]);

async function assertAuthorized(userId) {
  if (!userId || typeof userId !== "string") {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }
  const doc = await admin.firestore().collection("sanad").doc("snd_u4").get();
  const users = doc.exists ? JSON.parse(doc.data().v || "[]") : [];
  const user = users.find((u) => u.id === userId);
  if (!user || !ALLOWED_ROLES.has(user.role) || user.status === "suspended") {
    throw new HttpsError("permission-denied", "غير مصرح لك باستخدام مولّد المحتوى الإعلاني");
  }
}

exports.generateAdContent = onCall({ secrets: [HF_KEY] }, async (request) => {
  const { userId, prompt, application, params } = request.data || {};
  await assertAuthorized(userId);

  if (!prompt || typeof prompt !== "string" || !prompt.trim()) {
    throw new HttpsError("invalid-argument", "الوصف (prompt) مطلوب");
  }

  const app = (application && String(application).trim()) || DEFAULT_APPLICATION;
  const body = { prompt: prompt.trim(), ...(params && typeof params === "object" ? params : {}) };

  let res;
  try {
    res = await fetch(`${HF_BASE_URL}/${app}`, {
      method: "POST",
      headers: {
        Authorization: `Key ${HF_KEY.value()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });
  } catch (e) {
    throw new HttpsError("unavailable", `تعذر الاتصال بـ Higgsfield: ${e.message}`);
  }

  const text = await res.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = null;
  }

  if (!res.ok || !data) {
    throw new HttpsError("internal", `Higgsfield error ${res.status}: ${text.slice(0, 500)}`);
  }

  return {
    requestId: data.request_id,
    statusUrl: data.status_url,
    cancelUrl: data.cancel_url,
  };
});

exports.checkAdContentStatus = onCall({ secrets: [HF_KEY] }, async (request) => {
  const { userId, statusUrl } = request.data || {};
  await assertAuthorized(userId);

  if (!statusUrl || typeof statusUrl !== "string" || !statusUrl.startsWith(`${HF_BASE_URL}/`)) {
    throw new HttpsError("invalid-argument", "statusUrl غير صالح");
  }

  let res;
  try {
    res = await fetch(statusUrl, {
      headers: { Authorization: `Key ${HF_KEY.value()}` },
    });
  } catch (e) {
    throw new HttpsError("unavailable", `تعذر الاتصال بـ Higgsfield: ${e.message}`);
  }

  const text = await res.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = null;
  }

  if (!res.ok || !data) {
    throw new HttpsError("internal", `Higgsfield error ${res.status}: ${text.slice(0, 500)}`);
  }

  return data;
});

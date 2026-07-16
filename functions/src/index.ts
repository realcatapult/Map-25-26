import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import Anthropic from "@anthropic-ai/sdk";
import * as admin from "firebase-admin";

// The Anthropic API key is stored as a Firebase secret, never shipped in the app.
// Set it once with:  firebase functions:secrets:set ANTHROPIC_API_KEY
const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");
const ADMIN_SIGNUP_CODE = defineSecret("ADMIN_SIGNUP_CODE");

if (admin.apps.length === 0) {
  admin.initializeApp();
}

// System prompt scopes Claude to *this* app so it answers support questions
// about GroupApp's real features rather than acting as a generic chatbot.
const SYSTEM_PROMPT = `You are the friendly support assistant for GroupApp, a mobile app for student clubs and groups.

GroupApp's features:
- Group chats: users create or join group chats. Public groups can be joined with a 6-character join code, or discovered on the Discover page. Private groups require an invite.
- Join codes: each group has a 6-character code (letters + numbers). Share it so others can join. Find it via the group's info (i) button.
- Direct messages: users can message each other one-on-one, including tapping "Message" next to a member in a group's info panel.
- Calendar & events: group admins/owners can add events (title, description, date, time) that appear on every member's home calendar. Filter which groups show via the calendar settings (tune) icon.
- Announcements & notifications: the home page shows recent group activity and announcements.
- Roles: a group has an owner (creator) and admins. Admins can change group settings (public/private, who can post, theme color/icon) and manage the admin list. "Who can post" can be set to all members or admins only.
- Profile: users set a first/last name and profile picture in Settings. Settings also has a Dark Mode toggle.

Guidelines:
- Be concise, warm, and practical. Give step-by-step instructions when explaining how to do something.
- Only answer questions about GroupApp. If asked something unrelated, gently redirect to app support topics.
- If you don't know an app-specific detail, say so and suggest contacting a human admin rather than inventing features.
- Never ask for or handle passwords, join codes, or personal data.`;

type ChatMessage = { role: "user" | "assistant"; content: string };

export const supportChat = onCall(
  {
    secrets: [ANTHROPIC_API_KEY],
    // Cap concurrency/instances to keep costs predictable.
    maxInstances: 10,
    region: "us-central1",
  },
  async (request) => {
    // Firebase Auth is enforced here — only signed-in users can call this.
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to use support chat.",
      );
    }

    const history = request.data?.messages as ChatMessage[] | undefined;
    if (!Array.isArray(history) || history.length === 0) {
      throw new HttpsError("invalid-argument", "messages must be a non-empty array.");
    }

    // Basic input hygiene: bound history length and message size.
    const trimmed = history.slice(-20).map((m) => ({
      role: m.role === "assistant" ? ("assistant" as const) : ("user" as const),
      content: String(m.content ?? "").slice(0, 4000),
    }));

    const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });

    try {
      const response = await client.messages.create({
        model: "claude-haiku-4-5",
        max_tokens: 1024,
        system: SYSTEM_PROMPT,
        messages: trimmed,
      });

      const reply = response.content
        .filter((b): b is Anthropic.TextBlock => b.type === "text")
        .map((b) => b.text)
        .join("")
        .trim();

      return { reply: reply || "Sorry, I couldn't generate a response. Please try again." };
    } catch (err) {
      console.error("Claude API error:", err);
      throw new HttpsError("internal", "The assistant is unavailable right now. Please try again.");
    }
  },
);

export const verifyAdminSignupCode = onCall(
  {
    secrets: [ADMIN_SIGNUP_CODE],
    region: "us-central1",
    maxInstances: 10,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }

    const rawCode = request.data?.code;
    const submittedCode = String(rawCode ?? "").trim();
    if (!submittedCode) {
      throw new HttpsError("invalid-argument", "Verification code is required.");
    }

    const expectedCode = ADMIN_SIGNUP_CODE.value().trim();
    if (!expectedCode) {
      throw new HttpsError(
        "failed-precondition",
        "Admin verification is not configured.",
      );
    }
    if (submittedCode != expectedCode) {
      throw new HttpsError("permission-denied", "Invalid verification code.");
    }

    const uid = request.auth.uid;
    const userRecord = await admin.auth().getUser(uid);
    const existingClaims = userRecord.customClaims || {};

    await admin.auth().setCustomUserClaims(uid, {
      ...existingClaims,
      schoolAdmin: true,
    });

    await admin.firestore().collection("users").doc(uid).set(
      {
        email: request.auth.token.email ?? null,
        schoolAdmin: true,
        schoolAdminVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        schoolAdminVerifiedBy: "verifyAdminSignupCode",
      },
      { merge: true },
    );

    return { success: true };
  },
);

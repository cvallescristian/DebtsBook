// Sends an APNs push to the other member of a connection when an activity is inserted.
//
// Triggered by a Database Webhook on INSERT into public.activities, which must send
// the header `x-webhook-secret: <WEBHOOK_SECRET>`. Deploy with --no-verify-jwt since
// the webhook secret, not a user JWT, authenticates the call.
//
// Secrets (supabase secrets set ...), never committed:
//   APNS_KEY       contents of the AuthKey_XXXXXXXXXX.p8 file
//   APNS_KEY_ID    the key's 10-character ID
//   APNS_TEAM_ID   Apple Developer Team ID
//   WEBHOOK_SECRET random string shared with the webhook
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { type ActivityRecord, isStale, message, recipientFor, timingSafeEqual } from "./logic.ts";

const BUNDLE_ID = "Cristian.DebtsBook";
const APNS_HOSTS: Record<string, string> = {
  sandbox: "https://api.sandbox.push.apple.com",
  production: "https://api.push.apple.com",
};

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function base64url(data: ArrayBuffer | Uint8Array | string): string {
  const bytes = typeof data === "string"
    ? new TextEncoder().encode(data)
    : new Uint8Array(data);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// APNs rejects provider tokens refreshed more than once per 20 minutes, so a warm
// instance reuses its token for 50 minutes (APNs accepts them for up to an hour).
let cachedJWT: { token: string; issuedAt: number } | null = null;

async function apnsJWT(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJWT && now - cachedJWT.issuedAt < 50 * 60) return cachedJWT.token;

  const pem = Deno.env.get("APNS_KEY")!
    .replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const header = base64url(JSON.stringify({ alg: "ES256", kid: Deno.env.get("APNS_KEY_ID") }));
  const claims = base64url(JSON.stringify({ iss: Deno.env.get("APNS_TEAM_ID"), iat: now }));
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  const token = `${header}.${claims}.${base64url(signature)}`;
  cachedJWT = { token, issuedAt: now };
  return token;
}

Deno.serve(async (req) => {
  const secret = Deno.env.get("WEBHOOK_SECRET");
  if (!secret || !timingSafeEqual(req.headers.get("x-webhook-secret") ?? "", secret)) {
    return new Response("Unauthorized", { status: 401 });
  }

  const payload = await req.json();
  if (payload?.type !== "INSERT" || payload?.table !== "activities") {
    return new Response("Ignored", { status: 200 });
  }
  const activity = payload.record as ActivityRecord;
  if (!activity?.actor_user_id) return new Response("No actor", { status: 200 });
  if (isStale(activity.date, Date.now())) {
    return new Response("Stale", { status: 200 });
  }

  const { data: connection } = await supabase
    .from("connections")
    .select("user_a, user_b")
    .eq("id", activity.connection_id)
    .single();
  if (!connection) return new Response("No connection", { status: 200 });

  const recipient = recipientFor(connection, activity.actor_user_id);
  if (!recipient) return new Response("No recipient", { status: 200 });

  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("token, env")
    .eq("user_id", recipient);
  if (!tokens?.length) return new Response("No devices", { status: 200 });

  // The name the recipient gave this friend in their own app.
  const { data: friend } = await supabase
    .from("friends")
    .select("name")
    .eq("owner_id", recipient)
    .eq("linked_user_id", activity.actor_user_id)
    .limit(1)
    .maybeSingle();

  const { title, body } = message(activity, friend?.name ?? "A friend");
  const apnsPayload = JSON.stringify({
    aps: {
      alert: { title, body },
      sound: "default",
      "thread-id": activity.connection_id,
    },
  });
  const jwt = await apnsJWT();

  await Promise.all(tokens.map(async ({ token, env }) => {
    const res = await fetch(`${APNS_HOSTS[env]}/3/device/${token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-collapse-id": activity.id,
      },
      body: apnsPayload,
    });
    if (res.status === 410 || res.status === 400) {
      const reason = (await res.json().catch(() => ({})))?.reason;
      if (res.status === 410 || reason === "BadDeviceToken") {
        await supabase.from("device_tokens").delete().eq("token", token);
      }
    } else {
      await res.body?.cancel();
    }
  }));

  return new Response("OK", { status: 200 });
});

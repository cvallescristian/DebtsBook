// Deletes the calling user's account and, through foreign key cascades, all of their data
// (profile, friends, groups, budgets, personal expenses/activity, connections and the
// shared expenses/activity in them, invites, device tokens). App Store guideline 5.1.1(v).
//
// Deployed WITH JWT verification (the default): only a signed-in user can call it, and it
// only ever deletes the user the JWT belongs to.
//
// If the user signed in with Apple, the app sends a fresh authorization code
// (`apple_authorization_code`) and the Apple tokens are revoked first, as Apple requires.
// Revocation is best effort: a failure is logged but never blocks deleting the account.
//
// Secrets (supabase secrets set ...), never committed:
//   SIWA_KEY       contents of the Sign in with Apple AuthKey_XXXXXXXXXX.p8 file
//   SIWA_KEY_ID    that key's 10-character ID
//   APNS_TEAM_ID   Apple Developer Team ID (shared with notify-activity)
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { APPLE_AUDIENCE, appleAuthorizationCode, appleClientSecretClaims, bearerToken } from "./logic.ts";

const CLIENT_ID = "Cristian.DebtsBook";

const admin = createClient(
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

async function appleClientSecret(): Promise<string | null> {
  const pemSource = Deno.env.get("SIWA_KEY");
  const keyID = Deno.env.get("SIWA_KEY_ID");
  const teamID = Deno.env.get("APNS_TEAM_ID");
  if (!pemSource || !keyID || !teamID) return null;

  const pem = pemSource.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "").replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);

  const header = base64url(JSON.stringify({ alg: "ES256", kid: keyID }));
  const claims = base64url(JSON.stringify(appleClientSecretClaims(teamID, CLIENT_ID, Math.floor(Date.now() / 1000))));
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(`${header}.${claims}`));
  return `${header}.${claims}.${base64url(signature)}`;
}

/** Exchanges the authorization code for a refresh token and revokes it. */
async function revokeApple(code: string): Promise<boolean> {
  const clientSecret = await appleClientSecret();
  if (!clientSecret) {
    console.error("Apple revocation skipped: SIWA secrets are not set");
    return false;
  }
  const tokenResponse = await fetch(`${APPLE_AUDIENCE}/auth/token`, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: CLIENT_ID, client_secret: clientSecret, code, grant_type: "authorization_code" }),
  });
  if (!tokenResponse.ok) {
    console.error(`Apple token exchange failed: ${tokenResponse.status}`);
    return false;
  }
  const tokens = await tokenResponse.json();
  const token = tokens.refresh_token ?? tokens.access_token;
  const tokenTypeHint = tokens.refresh_token ? "refresh_token" : "access_token";
  const revokeResponse = await fetch(`${APPLE_AUDIENCE}/auth/revoke`, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: CLIENT_ID, client_secret: clientSecret, token, token_type_hint: tokenTypeHint }),
  });
  if (!revokeResponse.ok) {
    console.error(`Apple revoke failed: ${revokeResponse.status}`);
    return false;
  }
  return true;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }
  const jwt = bearerToken(req.headers.get("authorization"));
  if (!jwt) {
    return new Response("Unauthorized", { status: 401 });
  }
  const { data, error } = await admin.auth.getUser(jwt);
  if (error || !data.user) {
    return new Response("Unauthorized", { status: 401 });
  }
  const userID = data.user.id;

  const body = await req.json().catch(() => null);
  const code = appleAuthorizationCode(body);
  const appleRevoked = code ? await revokeApple(code) : false;

  const { error: deleteError } = await admin.auth.admin.deleteUser(userID);
  if (deleteError) {
    console.error(`Deleting user failed: ${deleteError.message}`);
    return new Response(JSON.stringify({ error: "Could not delete the account" }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
  return new Response(JSON.stringify({ deleted: true, apple_revoked: appleRevoked }), {
    headers: { "content-type": "application/json" },
  });
});

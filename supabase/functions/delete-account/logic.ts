// Pure helpers for delete-account, kept separate so they can be unit tested.

export const APPLE_AUDIENCE = "https://appleid.apple.com";

/** The JWT from an `Authorization: Bearer <jwt>` header, or null. */
export function bearerToken(header: string | null): string | null {
  const match = header?.match(/^Bearer\s+(\S+)$/i);
  return match ? match[1] : null;
}

/** Claims for the client secret Apple requires on /auth/token and /auth/revoke. */
export function appleClientSecretClaims(teamID: string, clientID: string, nowSeconds: number) {
  return {
    iss: teamID,
    iat: nowSeconds,
    exp: nowSeconds + 5 * 60,
    aud: APPLE_AUDIENCE,
    sub: clientID,
  };
}

/** The authorization code the app sends when the user re-confirmed with Apple. */
export function appleAuthorizationCode(body: unknown): string | null {
  if (typeof body !== "object" || body === null) return null;
  const code = (body as Record<string, unknown>).apple_authorization_code;
  return typeof code === "string" && code.length > 0 ? code : null;
}

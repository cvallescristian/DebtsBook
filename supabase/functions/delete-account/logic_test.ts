import { assertEquals } from "jsr:@std/assert@1";
import { appleAuthorizationCode, appleClientSecretClaims, bearerToken } from "./logic.ts";

Deno.test("bearer token is read from the Authorization header only", () => {
  assertEquals(bearerToken("Bearer abc.def.ghi"), "abc.def.ghi");
  assertEquals(bearerToken("bearer abc"), "abc");
  assertEquals(bearerToken("Basic abc"), null);
  assertEquals(bearerToken("Bearer"), null);
  assertEquals(bearerToken(null), null);
});

Deno.test("Apple client secret is short-lived and addressed to Apple", () => {
  const claims = appleClientSecretClaims("TEAM123", "Cristian.DebtsBook", 1_000);
  assertEquals(claims, {
    iss: "TEAM123",
    iat: 1_000,
    exp: 1_300,
    aud: "https://appleid.apple.com",
    sub: "Cristian.DebtsBook",
  });
});

Deno.test("Apple authorization code is optional", () => {
  assertEquals(appleAuthorizationCode({ apple_authorization_code: "c0de" }), "c0de");
  assertEquals(appleAuthorizationCode({ apple_authorization_code: "" }), null);
  assertEquals(appleAuthorizationCode({ apple_authorization_code: 42 }), null);
  assertEquals(appleAuthorizationCode({}), null);
  assertEquals(appleAuthorizationCode(null), null);
});

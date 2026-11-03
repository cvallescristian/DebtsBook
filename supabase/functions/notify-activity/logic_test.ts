import { assertEquals } from "jsr:@std/assert@1";
import { type ActivityRecord, isStale, message, recipientFor, STALE_AFTER_MS, timingSafeEqual } from "./logic.ts";

const activity = (overrides: Partial<ActivityRecord> = {}): ActivityRecord => ({
  id: "a1",
  connection_id: "c1",
  type: "created",
  expense_title: "Dinner",
  amount: 30,
  actor_user_id: "alice",
  date: "2026-11-03T10:00:00Z",
  ...overrides,
});

Deno.test("webhook secret must match exactly", () => {
  assertEquals(timingSafeEqual("secret", "secret"), true);
  assertEquals(timingSafeEqual("secret", "secreT"), false);
  assertEquals(timingSafeEqual("secret", "secret "), false);
  assertEquals(timingSafeEqual("", "secret"), false);
});

Deno.test("fresh activity is not stale", () => {
  const date = "2026-11-03T10:00:00Z";
  const now = new Date(date).getTime() + STALE_AFTER_MS - 1;
  assertEquals(isStale(date, now), false);
});

Deno.test("history older than the window is stale", () => {
  const date = "2026-11-03T10:00:00Z";
  const now = new Date(date).getTime() + STALE_AFTER_MS + 1;
  assertEquals(isStale(date, now), true);
});

Deno.test("recipient is the member who didn't act", () => {
  assertEquals(recipientFor({ user_a: "alice", user_b: "bob" }, "alice"), "bob");
  assertEquals(recipientFor({ user_a: "alice", user_b: "bob" }, "bob"), "alice");
});

Deno.test("no recipient before the invite is redeemed", () => {
  assertEquals(recipientFor({ user_a: "alice", user_b: null }, "alice"), null);
});

Deno.test("actor never notifies themselves", () => {
  assertEquals(recipientFor({ user_a: "alice", user_b: "alice" }, "alice"), null);
});

Deno.test("messages per activity type", () => {
  assertEquals(message(activity(), "Ana"), {
    title: "Ana added an expense",
    body: "“Dinner” · $30.00",
  });
  assertEquals(message(activity({ type: "updated", amount: 12.5 }), "Ana").title, "Ana updated an expense");
  assertEquals(message(activity({ type: "deleted" }), "Ana"), {
    title: "Ana deleted an expense",
    body: "“Dinner”",
  });
  assertEquals(message(activity({ type: "paid" }), "Ana").title, "Ana marked an expense as paid");
  assertEquals(message(activity({ type: "settledUp", amount: 56.5 }), "Ana"), {
    title: "Ana settled up with you",
    body: "$56.50",
  });
  assertEquals(message(activity({ type: "unknown" }), "Ana").title, "Ana changed a shared expense");
});

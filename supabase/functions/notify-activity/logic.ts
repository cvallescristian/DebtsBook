// Pure helpers for index.ts, kept free of Deno.env and network so they can be unit tested.

export interface ActivityRecord {
  id: string;
  connection_id: string;
  type: string;
  expense_title: string;
  amount: number;
  actor_user_id: string | null;
  date: string;
  expense_id?: string | null;
}

export interface DevicePreferences {
  notify_expense_changes: boolean;
  notify_paid: boolean;
  notify_settled_up: boolean;
}

export const STALE_AFTER_MS = 10 * 60 * 1000;

export function timingSafeEqual(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a);
  const eb = new TextEncoder().encode(b);
  if (ea.length !== eb.length) return false;
  let diff = 0;
  for (let i = 0; i < ea.length; i++) diff |= ea[i] ^ eb[i];
  return diff === 0;
}

// A newly linked friend's whole history is inserted in one go; only notify about fresh changes.
export function isStale(activityDate: string, now: number): boolean {
  return now - new Date(activityDate).getTime() > STALE_AFTER_MS;
}

/** The connection member who didn't perform the action, or null if there's nobody to notify. */
export function recipientFor(
  connection: { user_a: string; user_b: string | null },
  actorUserID: string,
): string | null {
  const recipient = connection.user_a === actorUserID ? connection.user_b : connection.user_a;
  if (!recipient || recipient === actorUserID) return null;
  return recipient;
}

/** Whether a device's switches allow this activity type. Unknown types only follow the master switch. */
export function wantsNotification(device: DevicePreferences, type: string): boolean {
  switch (type) {
    case "created":
    case "updated":
    case "deleted":
      return device.notify_expense_changes;
    case "paid":
      return device.notify_paid;
    case "settledUp":
      return device.notify_settled_up;
    default:
      return true;
  }
}

export function message(activity: ActivityRecord, friendName: string): { title: string; body: string } {
  const title = `“${activity.expense_title}”`;
  const amount = `$${Number(activity.amount).toFixed(2)}`;
  switch (activity.type) {
    case "created":
      return { title: `${friendName} added an expense`, body: `${title} · ${amount}` };
    case "updated":
      return { title: `${friendName} updated an expense`, body: `${title} · ${amount}` };
    case "deleted":
      return { title: `${friendName} deleted an expense`, body: title };
    case "paid":
      return { title: `${friendName} marked an expense as paid`, body: `${title} · ${amount}` };
    case "settledUp":
      return { title: `${friendName} settled up with you`, body: amount };
    default:
      return { title: `${friendName} changed a shared expense`, body: title };
  }
}

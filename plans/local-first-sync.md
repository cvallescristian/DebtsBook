# Local-first sync plan

Status: proposed (2026-11-04). Not started.

## Goal

Two modes:

1. **Local mode (signed out):** all data lives on the device only.
2. **Signed-in mode:** all data lives on the device **and** in Supabase (friends, expenses, groups, budgets, activity). Pending Apple Pay items stay local-only.

## Source of truth

- **Local is the truth for the UI.** The app always reads and writes SwiftData, so it is instant and works offline.
- **Supabase is the truth for agreement** between devices and linked friends.
- **Conflicts:** every record has `updated_at`; the newest edit wins (last-write-wins).
- **Deletes are tombstones:** set `deleted_at` instead of deleting the row. "Missing on the server" must never mean "delete locally" (today's `ExpenseSyncService` / `ActivitySyncService` reconcile does this, and it wipes shared expenses when signing in with another account).
- **Offline:** every local change is marked dirty. When back online: push dirty records, then pull everything changed since the last sync cursor.

## Flows

| Situation | Behavior |
|---|---|
| Local mode, then sign in to a new account | Upload everything; device data now belongs to that account. |
| Sign in on a new phone (empty) | Download everything. |
| Local data + same person's existing account | Merge (UUIDs, no collisions). |
| Signed in, then sign in with a different account | Sheet: **Export Backup** / **Erase and Switch** / **Cancel** (signs out). Never sync before the user chooses. |
| Sync status | Cloud icon (like the friend "connected" icon): synced, syncing, offline with N pending. |

## Phases (one PR each, staging first)

1. **Account ownership + switch sheet.** Save the data owner's user ID at first sign-in. On a different account: empty device switches silently, otherwise block sync and show the sheet. `SyncCoordinator` refuses to sync when the signed-in user is not the owner. Reset App clears the owner. Unit tests for the decision, UI test for the sheet.
2. **Database.** Tables for groups, budgets and personal expenses; `updated_at` + `deleted_at` on every synced table; owner-only RLS. New migrations, never edit applied ones.
3. **Sync engine.** Dirty flags, tombstones, last-write-wins, pull-since-cursor. Replace the "missing = deleted" reconcile.
4. **First upload + cloud status icon.**

## Notes

- Backup export includes all local data (including synced copies of shared expenses) but not sync links (`remoteID`, `connectionID`, `linkedUserID`) or pending Apple Pay items. A restored backup is local-only; friends must be re-invited.
- Signing out today keeps local data. Signing in with a different account today pulls that account's friends on top and deletes shared expenses for linked friends locally (server copy is safe). Phase 1 fixes this.
- Google sign-in is on hold (planned approach: Supabase web OAuth flow, no SDK).

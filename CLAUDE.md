# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

DebtsBook is an iOS app (SwiftUI + SwiftData) for tracking shared expenses with friends and personal spending with group budgets. Core expense/friend/budget data lives entirely on-device in SwiftData — no account is required to use the app. An optional Supabase backend layered on top lets a user sign in and link up with one other person per friend to keep a shared expense history in sync between both of their devices.

## Commands

Build and test via `xcodebuild` (no CocoaPods/SPM CLI workflow beyond what Xcode resolves automatically):

```sh
# Build for testing
xcodebuild build-for-testing -scheme DebtsBook -project DebtsBook.xcodeproj -destination 'platform=iOS Simulator,name=<device>'

# Run the full test suite
xcodebuild test-without-building -scheme DebtsBook -project DebtsBook.xcodeproj -destination 'platform=iOS Simulator,name=<device>'

# Run a single test (Swift Testing syntax)
xcodebuild test-without-building -scheme DebtsBook -project DebtsBook.xcodeproj -destination 'platform=iOS Simulator,name=<device>' -only-testing:DebtsBookTests/ExpenseModelTests/splitEquallyOwesHalf
```

Pick an available simulator name with `xcrun xctrace list devices`. Tests use the **Swift Testing** framework (`import Testing`, `@Test`, `#expect`), not XCTest — see `DebtsBookTests/`.

In practice it's usually faster to open `DebtsBook.xcodeproj` in Xcode and use ⌘B / ⌘U.

### Local setup

Supabase-backed features (auth, friend linking, sync) require `DebtsBook/DebtsBook/Secrets.swift`, copied from `Secrets.swift.example` and filled in with a Supabase project's URL/anon key. This file is git-ignored. Without it, sync-related code won't have valid credentials — the rest of the app (adding friends/expenses/groups/budgets locally) doesn't depend on it.

## Architecture

### Local-first data model (SwiftData)

All domain models live in `DebtsBook/Models/` as `@Model` classes: `Friend`, `Expense`, `ExpenseGroup`, `Budget`, `Activity`. The single `ModelContainer` is created once in `DebtsBookApp.swift` and injected via `.modelContainer(container)`; views read/write it through `@Environment(\.modelContext)` and `@Query`.

Key relationships and rules:
- `Expense.friend` / `Expense.group` and `Budget.group` are `@Relationship(deleteRule: .nullify)` — deleting a friend or group must not leave a dangling reference. `DataIntegrityService.repairDanglingRelationships` runs once at launch (only on the real on-disk store, not in tests) to fix up any data saved before this rule existed; don't remove it without understanding that history.
- `Expense.isPersonal` (no `friend`) means no debt exists — budgets only ever count personal expenses, never friend-shared ones (see `exceededBudgetWarnings` in `BudgetModel.swift`).
- `owedAmount` / `signedAmount` / `loggedAmount` on `Expense` encode the splitting logic (`.equally` halves the amount, `.fullAmount` doesn't) and are the source of truth for balances — read these before changing split behavior instead of recomputing it elsewhere.
- `Activity` is an append-only log of expense actions (created/updated/deleted/paid/settledUp) rendered in the Activity tab; its `performedByMe` flag flips the wording between "You added…" and "`<friend>` added…" for entries pulled from a linked friend's side.

### Test host and in-memory container

`TestSupport.swift` detects the XCTest bundle host (`XCTestConfigurationFilePath` env var) and both the app and tests share one in-memory `ModelContainer` (`TestModelContainer.shared`) — SwiftData traps if two containers for the same `@Model` types are alive in one process. When adding a new `@Model` type, register it in **both** `DebtsBookApp.swift`'s real container and `TestModelContainer.shared`, or tests will crash.

### Optional Supabase sync layer

Everything under `DebtsBook/DebtsBook/Services/` (note: nested one level deeper than `Models`/`Views`) is the sync layer, built on `supabase-swift`:

- `SupabaseManager` — holds the single `SupabaseClient`, built from `Secrets.swift`.
- `AuthService` — magic link (OTP), Sign in with Apple, and session restore/URL-callback handling (`debtsbook://login-callback`).
- `ConnectService` — creates a shared `connections` row plus a redeemable invite code per friend; `redeemInvite` calls a Postgres RPC. A connection has at most two members (`user_a`/`user_b`).
- `FriendSyncService` — pushes/pulls `Friend` rows keyed by `remoteID`, and resolves `linkedUserID` once an invite is redeemed.
- `ExpenseSyncService` — pushes/pulls `Expense` rows for a linked friend's connection; server is authoritative for anything previously synced (a synced expense missing from a fresh pull gets deleted locally).
- `ActivitySyncService` — same pattern for `Activity`.
- `DataIntegrityService` — the launch-time repair pass described above.
- `BackupService` — local JSON export/import of the whole SwiftData store (independent of Supabase).

The sync flow has a specific ordering that matters when touching this code:
1. History (expenses/activity) is **not** pushed to a newly-created invite — the other person's real user ID doesn't exist yet, so a "friend paid" expense couldn't resolve a payer.
2. Once the invite is redeemed, the next `FriendSyncService.pullFriends` notices `linkedUserID` resolving for the first time and re-pushes that friend's full expense/activity history in one go.
3. `push(expense:)` / sync methods across these services guard on `friend.linkedUserID != nil`, not just `connectionID`, for this reason — don't relax that guard without preserving the ordering.
4. Disconnecting a friend clears `connectionID`/`linkedUserID` and nulls out `remoteID` on that friend's expenses/activities (their Supabase rows cascade-delete via `connections`), while keeping the local copy each side has already synced.
5. `ExpenseSyncService` tracks in-flight `remoteID`s (`pendingPushIDs`) so a pull racing an unfinished push can't delete the local row out from under it.

RLS policies backing all of this live in `supabase/migrations/`, applied in numeric order — the SQL comments there call out ordering hazards (e.g. `0002_shared_expenses.sql` is destructive and only safe to run once on a fresh project). When changing sync behavior, check whether the corresponding policy/columns need a new migration file rather than editing an already-applied one.

### View structure

Views are grouped by feature under `DebtsBook/Views/` (`Friends/`, `Groups/`, `Expenses/`, `Reports/`, `Activity/`, `Profile/`), each typically with `...View` (list), `...DetailView`, `...NewView`, `...EditView`. `RootView` gates the UI on session restore → optional Face ID lock (`requireFaceID` in `@AppStorage`) → `MainTabView`, and triggers a `FriendSyncService.pullFriends` whenever `AuthService.isSignedIn` flips true. Auth-specific screens (`AuthView`, invite flows) live directly under `DebtsBook/DebtsBook/Views/` rather than the feature-grouped `DebtsBook/Views/` tree — check both locations when looking for a view.

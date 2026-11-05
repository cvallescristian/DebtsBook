# DebtsBook

An iOS app for tracking shared expenses with friends and managing personal spending with group budgets. Know who owes what, set spending limits, and keep your finances in check. Everything works on-device with no account required; sign in to back up your data and share expenses with friends who also use DebtsBook.

Built with SwiftUI and [SwiftData](https://developer.apple.com/documentation/swiftdata), with an optional [Supabase](https://supabase.com) backend for accounts and sync.

## Features

- **Friends & Groups**: add friends to track shared debts, and create expense groups (e.g. Food, Transport) to categorise personal spending.
- **Expenses**: log expenses with a title, amount, date, and optional comment. Mark them as shared with a friend or personal ("Just Me"), and optionally assign a group.
- **Flexible splitting**: choose who paid and how it's split: equally (50/50) or one side owed the full amount.
- **Settle up**: mark individual expenses as paid, or settle everything with a friend in one tap.
- **Budgets & Reports**: set weekly, monthly, or yearly spending limits globally and per group. Track progress with visual indicators that go from green to orange to red as you approach or exceed your budget.
- **Activity log**: a chronological feed of all expense actions (created, updated, deleted, settled).
- **Account sync**: sign in with Apple or a magic link to back up friends, groups, budgets, expenses, and activity to your account. Changes sync automatically after every edit, and the Profile tab shows sync status and pending changes.
- **Shared expenses with friends**: invite a friend with a code to link up; shared expenses and activity stay in sync on both devices, with optional push notifications when they change.
- **Apple Pay capture**: a Shortcuts automation turns Apple Pay payments into pending expenses to review.
- **Backup**: export and import all data as a JSON file.
- **Delete account**: remove your account and all its data from the server, right from the app.
- **Face ID lock**: optionally require Face ID (with passcode fallback) to open the app.
- **Appearance**: switch between system, light, or dark mode.

## Requirements

- Xcode
- iOS 26.5+

## Getting Started

1. Clone the repository.
2. Open `DebtsBook.xcodeproj` in Xcode (Swift packages, including `supabase-swift`, resolve automatically).
3. Optional, for sign-in and sync: copy `DebtsBook/DebtsBook/Secrets.swift.example` to `Secrets.swift` (git-ignored) and fill in your Supabase project's URL and anon key. Then apply `supabase/migrations/` in numeric order and deploy the Edge Functions in `supabase/functions/`.
4. Build and run on a simulator or device (⌘R).

Without `Secrets.swift` configured, everything local (friends, expenses, groups, budgets) still works; only sign-in and sync are unavailable.

## Project Structure

```
DebtsBook/
├── Models/            # SwiftData models (Friend, Expense, ExpenseGroup, Budget, Activity, ...)
├── Views/
│   ├── Friends/       # Friends list, detail, create, and edit
│   ├── Groups/        # Groups list, detail, create, and edit
│   ├── Expenses/      # Expenses list, create, edit, and shared row/split UI
│   ├── Reports/       # Spending reports, budget cards, and budget editing
│   ├── Activity/      # Chronological activity log
│   └── Profile/       # Account, sync status, backup, appearance, and security settings
├── DebtsBook/
│   ├── Services/      # Data writes, auth, and Supabase sync
│   └── Views/         # Sign-in, invite, account switch, and delete account screens
└── Preview Content/   # Shared sample data for SwiftUI previews
supabase/
├── migrations/        # Database schema and RLS policies, applied in numeric order
└── functions/         # Edge Functions (push notifications, account deletion)
```

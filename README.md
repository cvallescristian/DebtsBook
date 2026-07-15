# DebtsBook

An iOS app for tracking shared expenses with friends and managing personal spending with group budgets. Know who owes what, set spending limits, and keep your finances in check — all on-device with no account required.

Built with SwiftUI and [SwiftData](https://developer.apple.com/documentation/swiftdata).

## Features

- **Friends & Groups** — add friends to track shared debts, and create expense groups (e.g. Food, Transport) to categorise personal spending.
- **Expenses** — log expenses with a title, amount, date, and optional comment. Mark them as shared with a friend or personal ("Just Me"), and optionally assign a group.
- **Flexible splitting** — choose who paid and how it's split: equally (50/50) or one side owed the full amount.
- **Settle up** — mark individual expenses as paid, or settle everything with a friend in one tap.
- **Budgets & Reports** — set weekly, monthly, or yearly spending limits globally and per group. Track progress with visual indicators that go from green to orange to red as you approach or exceed your budget.
- **Activity log** — a chronological feed of all expense actions (created, updated, deleted, settled).
- **Face ID lock** — optionally require Face ID (with passcode fallback) to open the app.
- **Appearance** — switch between system, light, or dark mode.

## Requirements

- Xcode
- iOS 26.5+

## Getting Started

1. Clone the repository.
2. Open `DebtsBook.xcodeproj` in Xcode.
3. Build and run on a simulator or device (⌘R).

No external dependencies — everything is built on native SwiftUI and SwiftData.

## Project Structure

```
DebtsBook/
├── Models/            # SwiftData models (Friend, Expense, ExpenseGroup, Budget, Activity)
├── Views/
│   ├── Friends/       # Friends list, detail, create, and edit
│   ├── Groups/        # Groups list, detail, create, and edit
│   ├── Expenses/      # Expenses list, create, edit, and shared row/split UI
│   ├── Reports/       # Spending reports, budget cards, and budget editing
│   ├── Activity/      # Chronological activity log
│   └── Profile/       # Appearance and security settings
└── Preview Content/   # Shared sample data for SwiftUI previews
```

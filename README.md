# DebtsBook

A simple iOS app for keeping track of shared expenses and debts with friends — who paid, who owes what, and whether it's settled up.

Built with SwiftUI and [SwiftData](https://developer.apple.com/documentation/swiftdata).

## Features

- **Friends** — add friends and see your running balance with each one at a glance (owed to you in green, owed by you in red, settled up otherwise).
- **Expenses** — log an expense with a title, amount, date, and an optional comment.
- **Flexible splitting** — choose who paid and how it's split: equally, or one side owed the full amount.
- **Settle up** — mark individual expenses as paid, or settle everything with a friend in one tap.
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
├── Models/          # SwiftData models (Friend, Expense) and app settings
├── Views/
│   ├── Friends/      # Friends list, detail, create, and edit
│   ├── Expenses/     # Expenses list, create, edit, and shared row/split UI
│   └── Profile/      # Appearance and security settings
└── Preview Content/  # Shared sample data for SwiftUI previews
```

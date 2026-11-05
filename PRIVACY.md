# Privacy Policy

_Last updated: November 6, 2026_

DebtsBook ("the app") is built to keep your financial data private. This policy explains what is collected, how it's used, and your choices.

## Local-only mode

By default, DebtsBook stores all data (friends, expenses, groups, budgets, and activity) directly on your device using Apple's SwiftData framework. No account is required, and nothing is sent off your device unless you choose to sign in (see below).

## Data collected when you sign in

Signing in is optional and creates an account, provided via Supabase. Once you're signed in, the following is stored on our servers (hosted by Supabase) so your data is backed up and kept in sync:

- **Email address**: used to authenticate your account (via magic-link sign-in or Sign in with Apple) and to identify you to friends you connect with. With Sign in with Apple, this may be an Apple private relay address.
- **Your data**: friends, groups, budgets, expenses (titles, amounts, dates, comments, split type, and settled status), and activity log entries.
- **Device token**: if you turn on notifications, your device's push notification token, used only to notify you when a connected friend adds, edits, or settles a shared expense.

Apple Pay payments captured through the Shortcuts automation stay on your device as pending expenses and are never sent to our servers unless you turn one into an expense. JSON backups you export are saved only where you choose.

## Sharing with a connected friend

If you connect with a friend using an invite code, the expenses you share with that friend and their activity log entries are visible to both of you, along with your email address. Everything else in your account is visible only to you.

Your data is never sold, shared with third parties, or used for advertising.

## What we don't do

- We don't use tracking technologies or third-party analytics/advertising SDKs.
- We don't access your contacts, camera, photos, or location.
- We don't sell or share your data with third parties.

## Face ID

If you enable the app lock feature, Face ID (or passcode fallback) is used to authenticate you locally. This authentication happens entirely on-device via Apple's Face ID APIs. No biometric data is ever collected, stored, or transmitted by DebtsBook.

## Data deletion

You can delete your locally stored data at any time from Profile > Reset App, or by deleting the app.

If you have an account, you can delete it from Profile > Delete Account. This permanently removes your account and all of its data from our servers, including expenses and activity shared with connected friends. If you signed in with Apple, your Sign in with Apple authorization is revoked as well. Copies already on a friend's device stay on that device.

## Contact

For privacy questions or data deletion requests, open an issue at:
https://github.com/cvallescristian/DebtsBook/issues

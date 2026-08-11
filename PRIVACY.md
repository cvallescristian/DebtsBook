# Privacy Policy

_Last updated: August 11, 2026_

DebtsBook ("the app") is built to keep your financial data private. This policy explains what is collected, how it's used, and your choices.

## Local-only mode

By default, DebtsBook stores all data — friends, expenses, groups, budgets, and activity — directly on your device using Apple's SwiftData framework. No account is required, and nothing is sent off your device unless you choose to connect with a friend (see below).

## Data collected when you connect with a friend

Connecting with another DebtsBook user to share expenses requires an account, provided via Supabase. When you create an account and connect with a friend, the following is stored on our servers (hosted by Supabase):

- **Email address** — used to authenticate your account (via magic-link sign-in) and to identify you to friends you connect with.
- **Shared expense data** — titles, amounts, dates, comments, split type, and settled status for expenses you mark as shared with a connected friend.
- **Activity log entries** — a record of shared-expense actions (created, updated, deleted, settled) between you and a connected friend.

This data is only visible to you and the specific friend you're connected with. It is never sold, shared with third parties, or used for advertising.

## What we don't do

- We don't use tracking technologies or third-party analytics/advertising SDKs.
- We don't access your contacts, camera, photos, or location.
- We don't sell or share your data with third parties.

## Face ID

If you enable the app lock feature, Face ID (or passcode fallback) is used to authenticate you locally. This authentication happens entirely on-device via Apple's Face ID APIs — no biometric data is ever collected, stored, or transmitted by DebtsBook.

## Data deletion

You can delete your locally stored data at any time by deleting the app. If you've connected with friends via an account, contact us (see below) to request deletion of your account and associated shared data from our servers.

## Contact

For privacy questions or data deletion requests, open an issue at:
https://github.com/cvallescristian/DebtsBook/issues

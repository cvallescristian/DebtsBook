-- Run this in the Supabase SQL editor after 0013_group_icon_color.sql.
-- Take a production backup first.
--
-- Per-device notification switches, read by the notify-activity Edge Function. They
-- default to true so devices registered by older builds (which don't send them) keep
-- getting every notification.
--
-- Activities also record which shared expense they're about, so tapping a push can open
-- it. No foreign key: a "deleted" activity outlives its expense.
--
-- Apply before shipping a build that sends these columns: its device token and activity
-- upserts fail against tables without them.

alter table public.device_tokens add column if not exists notify_expense_changes boolean not null default true;
alter table public.device_tokens add column if not exists notify_paid boolean not null default true;
alter table public.device_tokens add column if not exists notify_settled_up boolean not null default true;

alter table public.activities add column if not exists expense_id uuid;

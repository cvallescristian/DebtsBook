-- Run this in the Supabase SQL editor after 0006_shared_activity.sql.
--
-- Only needed if you already ran 0006 before this column was added to it —
-- harmless no-op otherwise. activities.actor_user_id records who performed
-- the action (for "You added…" vs "Ana added…" wording); paid_by_user_id is
-- the separate, direction-of-debt concept mirroring expenses.paid_by_user_id
-- (for "You owe/get back…" wording), which was missing before.

alter table public.activities add column if not exists paid_by_user_id uuid;

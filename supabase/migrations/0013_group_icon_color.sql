-- Run this in the Supabase SQL editor after 0012_paid_by_set_null.sql.
-- Take a production backup first.
--
-- Groups get an optional SF Symbol icon and a colour name. Both are nullable so rows
-- pushed by older app builds (which don't send these columns) keep working, and an
-- upsert from an older build leaves the existing values untouched.
--
-- Apply before shipping a build that syncs these fields: that build includes them in
-- every group push, which fails against a table without the columns.

alter table public.expense_groups add column if not exists icon_name text;
alter table public.expense_groups add column if not exists color_name text;

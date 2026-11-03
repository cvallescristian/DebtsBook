-- Run this in the Supabase SQL editor after 0007_activity_paid_by_user_id.sql.
--
-- APNs device tokens for push notifications. Each user can only see and manage
-- their own rows; the notify-activity Edge Function reads them with the service
-- role to find the recipient's devices.

create table if not exists public.device_tokens (
  token text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  env text not null check (env in ('sandbox', 'production')),
  updated_at timestamptz not null default now()
);

alter table public.device_tokens enable row level security;

drop policy if exists "Users manage their own device tokens" on public.device_tokens;
create policy "Users manage their own device tokens"
  on public.device_tokens for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select, insert, update, delete on public.device_tokens to authenticated;

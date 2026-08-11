-- Run this in the Supabase SQL editor after 0005_fix_inviter_linked_user_id.sql.
--
-- Mirrors the expenses table so the Activity log is shared between connected
-- accounts the same way expenses are: scoped to a connection, cascade-deleted
-- with it on disconnect, and readable/writable only by its two members.

create table if not exists public.activities (
  id uuid primary key,
  connection_id uuid not null references public.connections (id) on delete cascade,
  type text not null,
  expense_title text not null default '',
  amount numeric not null default 0,
  actor_user_id uuid,
  paid_by_user_id uuid,
  date timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.activities enable row level security;

drop policy if exists "Connection members can manage activities" on public.activities;
create policy "Connection members can manage activities"
  on public.activities for all
  to authenticated
  using (exists (
    select 1 from public.connections c
    where c.id = activities.connection_id and auth.uid() in (c.user_a, c.user_b)
  ))
  with check (exists (
    select 1 from public.connections c
    where c.id = activities.connection_id and auth.uid() in (c.user_a, c.user_b)
  ));

grant select, insert, update, delete on public.activities to authenticated;

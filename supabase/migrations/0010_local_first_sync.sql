-- Run this in the Supabase SQL editor after 0009_service_role_grants.sql.
-- Additive only (new tables, columns, triggers, indexes): safe to run on a live project.
--
-- Phase 2 of plans/local-first-sync.md. Every synced table gets:
--   updated_at  set by the server on every write. It is the pull-since cursor and the
--               last-write-wins clock (server receipt time, so an offline edit pushed
--               later wins over an earlier synced one).
--   deleted_at  tombstone. Rows are never hard-deleted by sync, so "missing on the
--               server" no longer has to mean "deleted".
-- Personal data (groups, budgets, personal expenses and their activity) lives in
-- owner-only tables, separate from the connection-shared expenses/activities, so the
-- notify-activity webhook (INSERT on activities) never fires for personal data.

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Existing synced tables ------------------------------------------------------------

alter table public.friends add column if not exists deleted_at timestamptz;
alter table public.friends add column if not exists icon_name text;

alter table public.expenses add column if not exists deleted_at timestamptz;

alter table public.activities add column if not exists updated_at timestamptz not null default now();
alter table public.activities add column if not exists deleted_at timestamptz;

drop trigger if exists set_updated_at on public.friends;
create trigger set_updated_at before insert or update on public.friends
  for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at on public.expenses;
create trigger set_updated_at before insert or update on public.expenses
  for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at on public.activities;
create trigger set_updated_at before insert or update on public.activities
  for each row execute function public.set_updated_at();

create index if not exists friends_owner_updated_idx on public.friends (owner_id, updated_at);
create index if not exists expenses_connection_updated_idx on public.expenses (connection_id, updated_at);
create index if not exists activities_connection_updated_idx on public.activities (connection_id, updated_at);

-- Groups --------------------------------------------------------------------------

create table if not exists public.expense_groups (
  id uuid primary key,
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  -- Target of the composite foreign keys below, so a budget or expense can only point
  -- at a group owned by the same user.
  unique (id, owner_id)
);

-- Budgets -------------------------------------------------------------------------

create table if not exists public.budgets (
  id uuid primary key,
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  group_id uuid,
  amount numeric not null,
  period text not null check (period in ('Week', 'Month', 'Year')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (group_id, owner_id) references public.expense_groups (id, owner_id) on delete set null (group_id)
);

-- Personal expenses ---------------------------------------------------------------

create table if not exists public.personal_expenses (
  id uuid primary key,
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  group_id uuid,
  title text not null,
  amount numeric not null,
  comment text,
  date timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (group_id, owner_id) references public.expense_groups (id, owner_id) on delete set null (group_id)
);

-- Personal activity (the Activity tab entries for expenses without a friend) -------

create table if not exists public.personal_activities (
  id uuid primary key,
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  type text not null,
  expense_title text not null default '',
  amount numeric not null default 0,
  date timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- RLS, grants, triggers and cursor indexes for the owner-only tables ----------------

do $$
declare
  t text;
begin
  foreach t in array array['expense_groups', 'budgets', 'personal_expenses', 'personal_activities'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('drop policy if exists "Owners manage their own rows" on public.%I', t);
    execute format(
      'create policy "Owners manage their own rows" on public.%I for all to authenticated '
      'using (owner_id = auth.uid()) with check (owner_id = auth.uid())', t);
    execute format('drop trigger if exists set_updated_at on public.%I', t);
    execute format(
      'create trigger set_updated_at before insert or update on public.%I '
      'for each row execute function public.set_updated_at()', t);
    execute format('create index if not exists %I on public.%I (owner_id, updated_at)', t || '_owner_updated_idx', t);
  end loop;
end $$;

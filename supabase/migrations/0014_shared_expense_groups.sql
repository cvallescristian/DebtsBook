-- Run this in the Supabase SQL editor after 0013_group_icon_color.sql.
-- Additive only (new table): safe to run on a live project. Take a production backup first.
--
-- A shared expense (connection-shared `expenses`) can sit in one of your groups so your
-- share counts in Reports. The group is yours, not the connection's: each member keeps
-- their own pick here, one row per (owner, expense).
--
-- Deleting the shared expense removes everyone's rows (cascade). Groups soft-delete
-- (deleted_at), so a row may still name a deleted group; the app ignores it on pull.
--
-- Apply before shipping a build that syncs these: that build reads this table on every
-- sync, and the sync shows as failed against a project without it.

create table if not exists public.shared_expense_groups (
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  expense_id uuid not null references public.expenses (id) on delete cascade,
  group_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, expense_id),
  foreign key (group_id, owner_id) references public.expense_groups (id, owner_id) on delete set null (group_id)
);

alter table public.shared_expense_groups enable row level security;
grant select, insert, update, delete on public.shared_expense_groups to authenticated;

-- The exists() runs under the expenses RLS policy, so it only passes for expenses in a
-- connection the caller belongs to.
drop policy if exists "Owners manage their own rows" on public.shared_expense_groups;
create policy "Owners manage their own rows" on public.shared_expense_groups
  for all to authenticated
  using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid()
    and exists (select 1 from public.expenses e where e.id = shared_expense_groups.expense_id)
  );

drop trigger if exists set_updated_at on public.shared_expense_groups;
create trigger set_updated_at before insert or update on public.shared_expense_groups
  for each row execute function public.set_updated_at();

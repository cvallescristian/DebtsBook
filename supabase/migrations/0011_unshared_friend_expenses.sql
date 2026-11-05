-- Run this in the Supabase SQL editor after 0010_local_first_sync.sql.
-- Additive only: safe to run on a live project.
--
-- 0010's personal tables had no place for expenses with a friend who isn't linked yet
-- (no connection, so they can't go in `expenses`). personal_expenses/personal_activities
-- now hold every expense and activity that isn't shared through a connection: friend_id
-- is null for "Just me", set for an unlinked friend. When the friend links, sync moves
-- the row to `expenses` (tombstone here, insert there).

-- Target of the composite foreign keys below, so a row can only point at a friend owned
-- by the same user.
alter table public.friends drop constraint if exists friends_id_owner_key;
alter table public.friends add constraint friends_id_owner_key unique (id, owner_id);

alter table public.personal_expenses add column if not exists friend_id uuid;
alter table public.personal_expenses add column if not exists paid_by_me boolean not null default true;
alter table public.personal_expenses add column if not exists split_type text not null default 'equally';
alter table public.personal_expenses add column if not exists is_settled boolean not null default false;

alter table public.personal_expenses drop constraint if exists personal_expenses_split_type_check;
alter table public.personal_expenses add constraint personal_expenses_split_type_check
  check (split_type in ('equally', 'fullAmount'));

alter table public.personal_expenses drop constraint if exists personal_expenses_friend_fkey;
alter table public.personal_expenses add constraint personal_expenses_friend_fkey
  foreign key (friend_id, owner_id) references public.friends (id, owner_id) on delete set null (friend_id);

alter table public.personal_activities add column if not exists friend_id uuid;
alter table public.personal_activities add column if not exists friend_name text;
alter table public.personal_activities add column if not exists paid_by_me boolean not null default true;

alter table public.personal_activities drop constraint if exists personal_activities_friend_fkey;
alter table public.personal_activities add constraint personal_activities_friend_fkey
  foreign key (friend_id, owner_id) references public.friends (id, owner_id) on delete set null (friend_id);

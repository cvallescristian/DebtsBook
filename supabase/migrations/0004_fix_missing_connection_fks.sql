-- Run this in the Supabase SQL editor after 0003_disconnect.sql.
--
-- friends.connection_id and invites.connection_id were added via
-- `add column if not exists` in 0002, which silently skipped re-adding the
-- `references ... on delete set null/cascade` clause on repeated runs of the
-- migration (the column already existed, so the whole ALTER TABLE was a
-- no-op). As a result neither ever actually had a foreign key, so deleting
-- a connections row never cleared the stale connection_id on either side.

-- Clean up any dangling references left over from that gap before adding
-- the constraints (Postgres validates existing rows when adding a FK).
update public.friends f
set connection_id = null
where connection_id is not null
  and not exists (select 1 from public.connections c where c.id = f.connection_id);

update public.invites i
set connection_id = null
where connection_id is not null
  and not exists (select 1 from public.connections c where c.id = i.connection_id);

alter table public.friends
  drop constraint if exists friends_connection_id_fkey;
alter table public.friends
  add constraint friends_connection_id_fkey
  foreign key (connection_id) references public.connections (id) on delete set null;

alter table public.invites
  drop constraint if exists invites_connection_id_fkey;
alter table public.invites
  add constraint invites_connection_id_fkey
  foreign key (connection_id) references public.connections (id) on delete cascade;

-- Run this in the Supabase SQL editor after 0001_friends_sync.sql.
-- Safe to run multiple times: drops and recreates everything this migration owns first.

drop table if exists public.expenses cascade;
drop table if exists public.connections cascade;
drop function if exists public.redeem_invite(text);

create table public.connections (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles (id) on delete cascade,
  user_b uuid references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.connections enable row level security;
grant select, insert, update, delete on public.connections to authenticated;

create policy "Users create connections as user_a"
  on public.connections for insert
  to authenticated
  with check (user_a = auth.uid());

create policy "Members can view their connections"
  on public.connections for select
  to authenticated
  using (auth.uid() in (user_a, user_b));

create policy "Members can update their connections"
  on public.connections for update
  to authenticated
  using (auth.uid() in (user_a, user_b))
  with check (auth.uid() in (user_a, user_b));

alter table public.friends
  add column if not exists connection_id uuid references public.connections (id) on delete set null;

alter table public.invites
  add column if not exists connection_id uuid references public.connections (id) on delete cascade;

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.connections (id) on delete cascade,
  title text not null,
  amount numeric not null,
  is_settled boolean not null default false,
  paid_by_user_id uuid references public.profiles (id),
  split_type text not null default 'equally',
  comment text,
  date timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.expenses enable row level security;
grant select, insert, update, delete on public.expenses to authenticated;

create policy "Connection members manage shared expenses"
  on public.expenses for all
  to authenticated
  using (exists (
    select 1 from public.connections c
    where c.id = expenses.connection_id
      and auth.uid() in (c.user_a, c.user_b)
  ))
  with check (exists (
    select 1 from public.connections c
    where c.id = expenses.connection_id
      and auth.uid() in (c.user_a, c.user_b)
  ));

-- security definer: a redeemer can't otherwise see the inviter's row under RLS.
create function public.redeem_invite(invite_code text)
returns table (inviter_name text) as $$
declare
  v_invite public.invites;
  v_redeemer_id uuid := auth.uid();
begin
  select * into v_invite
  from public.invites
  where code = invite_code
    and not redeemed
    and expires_at > now()
  for update;

  if v_invite is null then
    raise exception 'Invalid or expired invite code';
  end if;

  if v_invite.inviter_id = v_redeemer_id then
    raise exception 'You cannot redeem your own invite';
  end if;

  update public.connections
  set user_b = v_redeemer_id
  where id = v_invite.connection_id
    and user_b is null;

  if not found then
    raise exception 'This invite has already been redeemed';
  end if;

  insert into public.friends (owner_id, name, linked_user_id, connection_id)
  select v_redeemer_id, p.email, p.id, v_invite.connection_id
  from public.profiles p
  where p.id = v_invite.inviter_id;

  update public.invites set redeemed = true where code = invite_code;

  return query
    select p.email from public.profiles p where p.id = v_invite.inviter_id;
end;
$$ language plpgsql security definer;

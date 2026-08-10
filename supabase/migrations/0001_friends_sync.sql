-- Run this in the Supabase SQL editor (or via `supabase db push`) for your project.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Profiles are viewable by any authenticated user"
  on public.profiles for select
  to authenticated
  using (true);

create policy "Users manage their own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create table if not exists public.friends (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  linked_user_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.friends enable row level security;

create policy "Owners manage their own friends"
  on public.friends for all
  to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create table if not exists public.invites (
  code text primary key,
  inviter_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  redeemed boolean not null default false
);

alter table public.invites enable row level security;

create policy "Inviters manage their own invites"
  on public.invites for all
  to authenticated
  using (auth.uid() = inviter_id)
  with check (auth.uid() = inviter_id);

-- security definer: a redeemer can't otherwise see the inviter's row (or the
-- inviter's row for a different user) under the RLS policies above.
create or replace function public.redeem_invite(invite_code text)
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

  insert into public.friends (owner_id, name, linked_user_id)
  select v_redeemer_id, p.email, p.id
  from public.profiles p
  where p.id = v_invite.inviter_id;

  insert into public.friends (owner_id, name, linked_user_id)
  select v_invite.inviter_id, p.email, p.id
  from public.profiles p
  where p.id = v_redeemer_id;

  update public.invites set redeemed = true where code = invite_code;

  return query
    select p.email from public.profiles p where p.id = v_invite.inviter_id;
end;
$$ language plpgsql security definer;

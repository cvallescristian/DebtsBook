-- Run this in the Supabase SQL editor after 0004_fix_missing_connection_fks.sql.
--
-- redeem_invite created the redeemer's friend row with linked_user_id set correctly,
-- but never updated the INVITER's existing friend row to link back to the redeemer.
-- That left the inviter's linked_user_id permanently NULL, so any expense they pushed
-- with "friend paid" got a paid_by_user_id matching neither connection member — both
-- sides then show it as "friend paid" instead of it flipping between the two views.

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

  update public.connections
  set user_b = v_redeemer_id
  where id = v_invite.connection_id
    and user_b is null;

  if not found then
    raise exception 'This invite has already been redeemed';
  end if;

  -- Link the inviter's existing friend row for this connection back to the redeemer.
  update public.friends
  set linked_user_id = v_redeemer_id
  where owner_id = v_invite.inviter_id
    and connection_id = v_invite.connection_id;

  insert into public.friends (owner_id, name, linked_user_id, connection_id)
  select v_redeemer_id, p.email, p.id, v_invite.connection_id
  from public.profiles p
  where p.id = v_invite.inviter_id;

  update public.invites set redeemed = true where code = invite_code;

  return query
    select p.email from public.profiles p where p.id = v_invite.inviter_id;
end;
$$ language plpgsql security definer;

-- Backfill any existing connections' friend rows that are missing (or have a wrong)
-- linked_user_id, so already-established connections get fixed retroactively too.
update public.friends f
set linked_user_id = case when f.owner_id = c.user_a then c.user_b else c.user_a end
from public.connections c
where f.connection_id = c.id
  and c.user_b is not null
  and f.linked_user_id is distinct from (case when f.owner_id = c.user_a then c.user_b else c.user_a end);

-- Run this in the Supabase SQL editor after 0008_device_tokens.sql.
--
-- The notify-activity Edge Function queries with the service role. It bypasses
-- RLS but still needs table privileges, which newer projects don't grant to
-- service_role by default. Grants only what that function uses.

grant select on public.connections to service_role;
grant select on public.friends to service_role;
grant select, delete on public.device_tokens to service_role;

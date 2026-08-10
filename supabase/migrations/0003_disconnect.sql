-- Run this in the Supabase SQL editor after 0002_shared_expenses.sql.

drop policy if exists "Members can delete their connections" on public.connections;
create policy "Members can delete their connections"
  on public.connections for delete
  to authenticated
  using (auth.uid() in (user_a, user_b));

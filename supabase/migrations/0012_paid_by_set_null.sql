-- Run this in the Supabase SQL editor after 0011_unshared_friend_expenses.sql.
-- Take a production backup first.
--
-- Account deletion (delete-account Edge Function) deletes the auth user and lets every
-- foreign key cascade. expenses.paid_by_user_id had no delete rule, so a leftover expense
-- naming the user as payer outside one of their connections would block the deletion.
-- Clearing the payer instead never blocks it.

alter table public.expenses drop constraint if exists expenses_paid_by_user_id_fkey;
alter table public.expenses add constraint expenses_paid_by_user_id_fkey
  foreign key (paid_by_user_id) references public.profiles (id) on delete set null;

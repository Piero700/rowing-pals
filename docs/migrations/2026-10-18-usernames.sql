-- Rowing Pals: usernames (decision 85, 2026-10-18).
-- Run on staging after the earlier migrations. Safe to run twice.
--
-- Every account has a unique username — lower case, 3–20 of a–z 0–9 . _, not starting or ending
-- with a dot — shown as @username and used to sign in instead of the email. Accounts made before
-- this choose one the next time they open the app. Signing in with a username goes through the
-- username-auth Edge Function, which looks the email up on the server: nobody can turn a username
-- into an email address.

alter table profiles add column if not exists username text;

alter table profiles drop constraint if exists profiles_username_valid;
alter table profiles add constraint profiles_username_valid
  check (username is null or username ~ '^[a-z0-9_]([a-z0-9._]{1,18})[a-z0-9_]$');

create unique index if not exists profiles_username_unique on profiles (username);

-- Whether a username can be taken (before an account exists, at sign-up; the caller's own counts
-- as free).
create or replace function username_available(p_username text)
returns boolean
language sql stable security definer set search_path = public as $$
  select lower(btrim(p_username)) ~ '^[a-z0-9_]([a-z0-9._]{1,18})[a-z0-9_]$'
     and not exists (
       select 1 from profiles
       where username = lower(btrim(p_username)) and (auth.uid() is null or id <> auth.uid())
     );
$$;

-- Sets the caller's username, with plain words for what's wrong.
create or replace function set_username(p_username text)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v text := lower(btrim(coalesce(p_username, '')));
begin
  if auth.uid() is null then raise exception 'Sign in first.'; end if;
  if char_length(v) < 3 then raise exception 'A username needs at least 3 characters.'; end if;
  if char_length(v) > 20 then raise exception 'A username can be at most 20 characters.'; end if;
  if v !~ '^[a-z0-9._]+$' then raise exception 'Use only letters, numbers, full stops and underscores.'; end if;
  if v ~ '^\.' or v ~ '\.$' then raise exception 'A username can''t start or end with a full stop.'; end if;
  if exists (select 1 from profiles where username = v and id <> auth.uid()) then
    raise exception 'That username is taken.';
  end if;
  update profiles set username = v where id = auth.uid();
  if not found then raise exception 'Finish setting up your account first.'; end if;
  return v;
end $$;

revoke all on function username_available(text) from public;
grant execute on function username_available(text) to anon, authenticated;
revoke all on function set_username(text) from public, anon;
grant execute on function set_username(text) to authenticated;

notify pgrst, 'reload schema';

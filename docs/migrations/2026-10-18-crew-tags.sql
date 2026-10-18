-- Crew tagging (v1.1, user 2026-10-18; decision 90).
-- Run once in the Supabase SQL editor, staging first. Safe to run again.
--
-- The person posting a session can tag the clubmates they trained with; the post then shows
-- "with Sam, Joe". Only clubmates who row can be tagged (not yourself, not coach-only accounts).
-- The poster sets the tags when posting and can change them afterwards; anyone tagged can remove
-- themselves. Tags are only a line on the post: no alert, nothing on the tagged rower's profile,
-- and their own metres never change. Who can see a post's tags is who can see the post.

begin;

-- One tagged person on one post. Its own id, so the API doesn't treat it as a second way from a
-- session to a profile (sessions → profiles stays the author).
create table if not exists session_tags (
  id         uuid primary key default gen_random_uuid(),
  session_id uuid not null references sessions on delete cascade,
  user_id    uuid not null references profiles on delete cascade,
  created_at timestamptz not null default now(),
  unique (session_id, user_id)
);
create index if not exists session_tags_user_idx on session_tags (user_id);
alter table session_tags enable row level security;

-- Seen by whoever can see the post (the sessions policies decide, inside this check).
drop policy if exists read_with_post on session_tags;
create policy read_with_post on session_tags for select to authenticated
  using (exists (select 1 from sessions s where s.id = session_tags.session_id));

-- The poster sets who they trained with: exactly these people, clubmates who row. Replaces the
-- post's tags; an empty list clears them.
create or replace function set_session_tags(p_session uuid, p_users uuid[])
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid;
  v_club uuid;
  v_users uuid[] := array(select distinct u from unnest(coalesce(p_users, '{}')) u where u is not null);
begin
  select user_id into v_owner from sessions where id = p_session;
  if v_owner is null then raise exception 'That post no longer exists.'; end if;
  if v_owner <> auth.uid() then raise exception 'Only the person who posted it can tag people.'; end if;
  if cardinality(v_users) > 20 then raise exception 'Tag up to 20 people.'; end if;
  if cardinality(v_users) > 0 then
    select club_id into v_club from profiles where id = v_owner;
    if v_club is null then raise exception 'Join a club to tag the people you trained with.'; end if;
    if exists (
      select 1 from unnest(v_users) u
      where u = v_owner
         or not exists (select 1 from profiles p where p.id = u and p.club_id = v_club and p.is_rower)
    ) then
      raise exception 'You can tag clubmates who row.';
    end if;
  end if;
  delete from session_tags where session_id = p_session and not (user_id = any(v_users));
  insert into session_tags (session_id, user_id)
    select p_session, u from unnest(v_users) u
  on conflict (session_id, user_id) do nothing;
end $$;

-- Someone tagged takes themselves off a post. The poster isn't told.
create or replace function remove_my_tag(p_session uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from session_tags where session_id = p_session and user_id = auth.uid();
end $$;

revoke all on function set_session_tags(uuid, uuid[]) from public, anon;
grant execute on function set_session_tags(uuid, uuid[]) to authenticated;
revoke all on function remove_my_tag(uuid) from public, anon;
grant execute on function remove_my_tag(uuid) to authenticated;

commit;

-- The API sees the new table and functions straight away.
notify pgrst, 'reload schema';

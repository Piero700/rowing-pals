-- Boat colours (user, 2026-10-18; decision 87).
-- Run once in the Supabase SQL editor, staging first, after 2026-10-17-rigging-and-announcements.sql
-- and 2026-10-18-coxed-quad.sql. Safe to run again.
--
-- A coach can colour a boat (any colour, kept as '#RRGGBB') so it's easy to pick out: on the
-- coach's screens and on the rower's Feed and Calendar. A saved boat keeps its colour, and adding
-- it to a session brings the colour with it. Changing only the colour of a sent boat doesn't make
-- it Not sent: nothing the crew needs to know has changed.

begin;

alter table saved_boats add column if not exists colour text;
alter table session_boats add column if not exists colour text;
alter table saved_boats drop constraint if exists saved_boats_colour_valid;
alter table saved_boats add constraint saved_boats_colour_valid check (colour is null or colour ~ '^#[0-9A-F]{6}$');
alter table session_boats drop constraint if exists session_boats_colour_valid;
alter table session_boats add constraint session_boats_colour_valid check (colour is null or colour ~ '^#[0-9A-F]{6}$');

-- A colour as it's stored: '#RRGGBB' in capitals, or null for none. Internal.
create or replace function checked_colour(p_colour text)
returns text
language plpgsql immutable as $$
declare
  v text := upper(nullif(btrim(coalesce(p_colour, '')), ''));
begin
  if v is null then return null; end if;
  if v !~ '^#[0-9A-F]{6}$' then raise exception 'Choose the boat''s colour again.'; end if;
  return v;
end $$;

-- As 2026-10-17-rigging-and-announcements.sql, with the colour.
drop function if exists save_saved_boat(uuid, text, text, text, text, jsonb);
create or replace function save_saved_boat(
  p_saved uuid, p_name text, p_type text, p_rigging text, p_sides text, p_seats jsonb, p_colour text default null
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
  v_id uuid := p_saved;
  v_sides text := checked_sides(p_type, p_rigging, p_sides);
  v_colour text := checked_colour(p_colour);
begin
  select club_id into v_club from profiles where id = auth.uid();
  if v_club is null or not is_club_coach(v_club) then raise exception 'Only your club''s coaches can save boats.'; end if;
  perform check_crew(v_club, p_type, p_seats);
  if v_id is null then
    insert into saved_boats (club_id, name, boat_type, rigging, sides, colour, created_by)
    values (v_club, btrim(p_name), p_type, coalesce(p_rigging, 'stroke'), v_sides, v_colour, auth.uid())
    returning id into v_id;
  else
    update saved_boats set name = btrim(p_name), boat_type = p_type, rigging = coalesce(p_rigging, 'stroke'),
                           sides = v_sides, colour = v_colour
    where id = v_id and club_id = v_club;
    if not found then raise exception 'That saved boat no longer exists.'; end if;
    delete from saved_boat_seats where saved_boat_id = v_id;
  end if;
  insert into saved_boat_seats (saved_boat_id, seat, user_id)
    select v_id, (v ->> 'seat')::int, (v ->> 'user')::uuid from jsonb_array_elements(coalesce(p_seats, '[]'::jsonb)) v;
  return v_id;
end $$;

-- As 2026-10-17-rigging-and-announcements.sql, with the colour (which doesn't un-send a boat).
drop function if exists save_session_boat(uuid, uuid, text, text, text, text, jsonb, boolean);
create or replace function save_session_boat(
  p_boat uuid, p_session uuid, p_name text, p_type text, p_rigging text, p_sides text, p_seats jsonb, p_keep_saved boolean,
  p_colour text default null
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_session water_sessions;
  v_id uuid := p_boat;
  v_old session_boats;
  v_old_seats jsonb;
  v_new_seats jsonb;
  v_clash text;
  v_saved uuid;
  v_sides text := checked_sides(p_type, p_rigging, p_sides);
  v_colour text := checked_colour(p_colour);
begin
  select * into v_session from water_sessions where id = p_session;
  if v_session.id is null then raise exception 'That water session no longer exists.'; end if;
  if not is_club_coach(v_session.club_id) then raise exception 'Only your club''s coaches can crew boats.'; end if;
  perform check_crew(v_session.club_id, p_type, p_seats);

  select p.display_name || ' is already in ' || b.name into v_clash
  from jsonb_array_elements(coalesce(p_seats, '[]'::jsonb)) v
  join session_boat_seats s on s.user_id = (v ->> 'user')::uuid
  join session_boats b on b.id = s.boat_id and b.session_id = p_session and b.id is distinct from p_boat
  join profiles p on p.id = s.user_id
  limit 1;
  if v_clash is not null then raise exception '%.', v_clash; end if;

  v_new_seats := coalesce((select jsonb_agg(jsonb_build_object('seat', (v ->> 'seat')::int, 'user', v ->> 'user') order by (v ->> 'seat')::int)
                           from jsonb_array_elements(coalesce(p_seats, '[]'::jsonb)) v), '[]'::jsonb);

  if v_id is null then
    insert into session_boats (session_id, position, name, boat_type, rigging, sides, colour)
    values (p_session, coalesce((select max(position) + 1 from session_boats where session_id = p_session), 0),
            btrim(p_name), p_type, coalesce(p_rigging, 'stroke'), v_sides, v_colour)
    returning id into v_id;
  else
    select * into v_old from session_boats where id = v_id and session_id = p_session;
    if v_old.id is null then raise exception 'That boat no longer exists.'; end if;
    v_old_seats := coalesce((select jsonb_agg(jsonb_build_object('seat', s.seat, 'user', s.user_id::text) order by s.seat)
                             from session_boat_seats s where s.boat_id = v_id), '[]'::jsonb);
    update session_boats set
      name = btrim(p_name), boat_type = p_type, rigging = coalesce(p_rigging, 'stroke'), sides = v_sides, colour = v_colour,
      sent_at = case when v_old.name = btrim(p_name) and v_old.boat_type = p_type
                          and v_old.rigging = coalesce(p_rigging, 'stroke') and v_old.sides is not distinct from v_sides
                          and v_old_seats = v_new_seats
                     then v_old.sent_at end
    where id = v_id;
    delete from session_boat_seats where boat_id = v_id;
  end if;
  insert into session_boat_seats (boat_id, seat, user_id)
    select v_id, (v ->> 'seat')::int, (v ->> 'user')::uuid from jsonb_array_elements(coalesce(p_seats, '[]'::jsonb)) v;

  if coalesce(p_keep_saved, false) then
    v_saved := save_saved_boat((select saved_boat_id from session_boats where id = v_id), p_name, p_type, p_rigging, v_sides, p_seats, v_colour);
    update session_boats set saved_boat_id = v_saved where id = v_id;
  else
    update session_boats set saved_boat_id = null where id = v_id;
  end if;
  return v_id;
end $$;

-- Adding a saved boat brings its colour too.
create or replace function add_saved_boat(p_saved uuid, p_session uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_session water_sessions;
  v_saved saved_boats;
  v_id uuid;
begin
  select * into v_session from water_sessions where id = p_session;
  select * into v_saved from saved_boats where id = p_saved;
  if v_session.id is null or v_saved.id is null then raise exception 'That boat or session no longer exists.'; end if;
  if not is_club_coach(v_session.club_id) or v_saved.club_id <> v_session.club_id then
    raise exception 'Only your club''s coaches can crew boats.';
  end if;
  insert into session_boats (session_id, position, name, boat_type, rigging, sides, colour, saved_boat_id)
  values (p_session, coalesce((select max(position) + 1 from session_boats where session_id = p_session), 0),
          v_saved.name, v_saved.boat_type, v_saved.rigging, v_saved.sides, v_saved.colour, v_saved.id)
  returning id into v_id;
  insert into session_boat_seats (boat_id, seat, user_id)
    select v_id, s.seat, s.user_id from saved_boat_seats s
    where s.saved_boat_id = p_saved
      and not exists (
        select 1 from session_boat_seats o join session_boats b on b.id = o.boat_id
        where b.session_id = p_session and b.id <> v_id and o.user_id = s.user_id
      );
  return v_id;
end $$;

revoke all on function checked_colour(text) from public, anon, authenticated;
revoke all on function save_saved_boat(uuid, text, text, text, text, jsonb, text) from public, anon;
grant execute on function save_saved_boat(uuid, text, text, text, text, jsonb, text) to authenticated;
revoke all on function save_session_boat(uuid, uuid, text, text, text, text, jsonb, boolean, text) from public, anon;
grant execute on function save_session_boat(uuid, uuid, text, text, text, text, jsonb, boolean, text) to authenticated;
revoke all on function add_saved_boat(uuid, uuid) from public, anon;
grant execute on function add_saved_boat(uuid, uuid) to authenticated;

commit;

-- The API sees the new column and functions straight away.
notify pgrst, 'reload schema';

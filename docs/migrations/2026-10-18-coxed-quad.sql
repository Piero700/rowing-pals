-- Rowing Pals: a coxed quad (decision 77, 2026-10-18).
-- Run on staging after 2026-10-17-rigging-and-announcements.sql. Safe to run twice.
--
-- Boat types become 1x 2x 2- 4- 4+ 4x 4x+ 8+: the coxed quad has four scullers and a cox.

-- MARK: - Boat types

create or replace function boat_rowers(p_type text)
returns int
language sql immutable as $$
  select case p_type when '1x' then 1 when '2x' then 2 when '2-' then 2
                     when '4-' then 4 when '4+' then 4 when '4x' then 4 when '4x+' then 4 when '8+' then 8 end;
$$;

create or replace function boat_is_coxed(p_type text)
returns boolean
language sql immutable as $$
  select p_type in ('4+', '4x+', '8+');
$$;

alter table saved_boats drop constraint if exists saved_boats_boat_type_check;
alter table saved_boats add constraint saved_boats_boat_type_check
  check (boat_type in ('1x', '2x', '2-', '4-', '4+', '4x', '4x+', '8+'));
alter table session_boats drop constraint if exists session_boats_boat_type_check;
alter table session_boats add constraint session_boats_boat_type_check
  check (boat_type in ('1x', '2x', '2-', '4-', '4+', '4x', '4x+', '8+'));

-- MARK: - Sides

-- As in 2026-10-17, with the coxed quad among the sculling boats. Internal (its grants are kept).
create or replace function checked_sides(p_type text, p_rigging text, p_sides text)
returns text
language plpgsql immutable as $$
begin
  if coalesce(p_rigging, 'stroke') not in ('stroke', 'bow', 'custom') then raise exception 'Choose the rigging.'; end if;
  if p_rigging = 'custom' then
    if p_type in ('1x', '2x', '4x', '4x+') then raise exception 'Sculling boats have no sides to set.'; end if;
    if p_sides is null or p_sides !~ '^[SB]+$' or char_length(p_sides) <> boat_rowers(p_type) then
      raise exception 'Give every seat a side.';
    end if;
    return p_sides;
  end if;
  return null;
end $$;

-- Minimum age 13, and protections for juniors (decision 107, user 2026-11-17). Run once in the
-- Supabase SQL editor, staging first, BEFORE installing the build that needs it (coaches read
-- rowers' details through coach_athlete_details). Safe to run again.
--
-- 1. A date of birth that makes someone under 13 can't be saved, and once given it can be changed
--    but not removed. (The app asks everyone for it: at sign-up, or once when they next open the
--    app. Someone under 13 is refused at sign-up, or their account is deleted.)
-- 2. Under 18 when they first give it: their account is made private (they can open it up again
--    in Settings).
-- 3. A junior's bodyweight is hidden from their club's coaches unless they've turned on "My parent
--    or guardian agrees". Coaches now read rowers' date of birth and bodyweight through
--    coach_athlete_details(), which applies that rule; they can no longer read the table directly.
--    A rower who hasn't given their date of birth yet is treated as a junior until they do.

begin;

-- MARK: - 1. The guardian's agreement

alter table athlete_private add column if not exists guardian_agrees_weight boolean not null default false;

-- MARK: - 2. Age rules on the date of birth

create or replace function athlete_private_age_rules()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' and old.birth_date is not null and new.birth_date is null then
    raise exception 'Your date of birth can be changed but not removed.';
  end if;
  if new.birth_date is not null and new.birth_date > (current_date - interval '13 years')::date then
    raise exception 'Rowing Pals is for people 13 and over.';
  end if;
  -- A junior's account starts private: the first time a date of birth under 18 is given.
  if new.birth_date is not null
     and (tg_op = 'INSERT' or old.birth_date is null)
     and new.birth_date > (current_date - interval '18 years')::date then
    update profiles set is_private = true where id = new.user_id;
  end if;
  return new;
end $$;

drop trigger if exists athlete_private_age_rules on athlete_private;
create trigger athlete_private_age_rules
  before insert or update on athlete_private
  for each row execute function athlete_private_age_rules();

-- MARK: - 3. What coaches see

drop policy if exists coach_read on athlete_private;

create or replace function coach_athlete_details(p_users uuid[])
returns table (user_id uuid, birth_date date, weight_kg numeric)
language sql stable security definer set search_path = public as $$
  select a.user_id,
         a.birth_date,
         case
           when a.birth_date is not null
                and (a.birth_date <= (current_date - interval '18 years')::date or a.guardian_agrees_weight)
             then a.weight_kg
         end
  from athlete_private a
  where a.user_id = any(coalesce(p_users, '{}'))
    and coaches_rower(a.user_id);
$$;
revoke all on function coach_athlete_details(uuid[]) from public, anon;
grant execute on function coach_athlete_details(uuid[]) to authenticated;

commit;

-- The API sees the new column and function straight away.
notify pgrst, 'reload schema';

-- Coach version, phase CV1 (decision 67, user 2026-10-16). Run once in the Supabase SQL editor,
-- staging first. Safe to run again.
--
-- A rower's side: the side they row on in a pair, four or eight. Coaches see it when they seat
-- them in a boat (phase CV3). Empty until the rower picks one; coach-only accounts never have one.
-- Read with the rest of the profile, changed by the rower in About you or Edit profile.

begin;

alter table profiles add column if not exists side text;

alter table profiles drop constraint if exists profiles_side_valid;
alter table profiles add constraint profiles_side_valid check (side is null or side in ('stroke', 'bow', 'both'));

commit;

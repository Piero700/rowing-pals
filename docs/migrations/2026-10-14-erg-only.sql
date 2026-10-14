-- Erg only (decision 54). Run once in the Supabase SQL editor, staging first. Safe to run again.
--
-- The app logs erg sessions only. Its "On-water rowing" club focus is gone: any club that chose it
-- becomes "All rowing", and the database no longer accepts it. (The unused water columns on
-- daily_totals and the 'water' session type are left alone: they hold no data.)

begin;

update clubs set focus = 'All rowing' where focus = 'On-water rowing';

alter table clubs drop constraint if exists clubs_focus_check;
alter table clubs add constraint clubs_focus_check
  check (focus in ('All rowing', 'Indoor rowing', 'University crew'));

commit;

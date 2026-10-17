-- Rowing Pals: Cox as a side (decision 78, 2026-10-18).
-- Run on staging after 2026-10-16-coach-version.sql. Safe to run twice.
--
-- The side picker at sign-up and in Edit profile is Stroke side · Bow side · Both · Cox, so a
-- profile's side may now be 'cox'. Coaches see it when crewing: coxes first for the cox seat, and
-- a Cox tag in a rowing seat.

alter table profiles drop constraint if exists profiles_side_valid;
alter table profiles add constraint profiles_side_valid
  check (side is null or side in ('stroke', 'bow', 'both', 'cox'));

-- Onboarding without a club (v3 §01 "I'm not in a club", decision 24).
-- Run once in the Supabase SQL editor, staging first. Safe to run again.

-- Set when a rower finishes onboarding, with or without a club. The app sends a rower
-- to onboarding only while this is empty AND they have no club, so existing accounts
-- are never sent back, even before this migration has run.
alter table profiles add column if not exists onboarded_at timestamptz;

-- Everyone already in a club has finished onboarding.
update profiles
set onboarded_at = created_at
where club_id is not null and onboarded_at is null;

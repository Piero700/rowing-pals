-- Redesign phase E, part 2: make photo access follow the same privacy rule.
-- Run AFTER 2026-09-23-private-accounts.sql (it needs can_view_user()).
-- Replaces the two "any signed-in user can read" policies with one that
-- allows a photo only when its owner is visible to the viewer. Photos live
-- at paths beginning with the owner's user id, e.g. <user_id>/<session_id>.jpg.
-- Upload policies (monitors_own_folder_insert, selfies_own_folder_insert)
-- are left alone. One transaction: the old policies are never removed
-- without the new one being added.
begin;

drop policy if exists monitors_read_all on storage.objects;
drop policy if exists selfies_read_all on storage.objects;

create policy read_visible_photos on storage.objects
  for select to authenticated
  using (
    bucket_id in ('monitors', 'selfies')
    and can_view_user(((storage.foldername(name))[1])::uuid)
  );

commit;

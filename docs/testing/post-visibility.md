# Who can see and comment on a post — test checklist

Decision 33 in `docs/design/v2-decisions.md`.

## 0. Run the migration on staging (do this first)
1. Open the Supabase dashboard and pick the **staging** project (not production).
2. Left sidebar → **SQL Editor** → **+ New query**.
3. Open `docs/migrations/2026-10-05-post-visibility.sql` in Xcode or any text editor, select
   everything (Cmd+A), copy (Cmd+C), paste it into the query box (Cmd+V).
4. Click **Run** (bottom right). Expect **Success. No rows returned**.
   If you see any red error, stop and send the whole error text to Claude.

## 1. Nothing you should see has gone (your phone, staging build)
- [ ] **Feed → Following** and **Feed → Club**: the same posts as before, with photos.
- [ ] Open a clubmate's post and a followed rower's post: photo, selfie, pieces, reactions and
      comments all load.
- [ ] Write a comment on a clubmate's post: it posts. React with an emoji: it sticks.
- [ ] Your own profile: recent activity and photos still show; open one of your posts.
- [ ] **Rankings**: Volume and Test results boards look the same as before.
- [ ] A comment alert still opens its post (needs a second account to comment on your post).

## 2. The database refuses what it should (SQL, staging)
Each test pretends to be one rower, then **ends on purpose with a red error box whose text is the
answer** (`RESULT: ...`). The error also undoes everything, so none of this changes your data. A
red box starting with `RESULT:` is success; any other error text is a problem — send it to Claude.

Same place: **SQL Editor → + New query → paste → Run**.

### Get the ids
```sql
select id, display_name, club_id, is_private from profiles order by created_at desc limit 20;
```
Pick **A**: a rower with at least one post. Pick **B**: a rower who is **not in A's club** and
does **not follow A**. Replace `A_ID` and `B_ID` below (keep the quotes).

### Test 1 — a stranger can't read A's posts or photos
```sql
do $$
declare s int; seg int; c int; p int;
begin
  set local role authenticated;
  perform set_config('request.jwt.claims', '{"sub":"B_ID","role":"authenticated"}', true);
  select count(*) into s   from sessions where user_id = 'A_ID';
  select count(*) into seg from segments g join sessions x on x.id = g.session_id where x.user_id = 'A_ID';
  select count(*) into c   from comments m where m.session_id in (select id from sessions where user_id = 'A_ID');
  select count(*) into p   from storage.objects
    where bucket_id in ('monitors','selfies') and (storage.foldername(name))[1] = 'A_ID';
  raise exception 'RESULT: posts=% pieces=% comments=% photos=%', s, seg, c, p;
end $$;
```
- [ ] Expect: `RESULT: posts=0 pieces=0 comments=0 photos=0`

### Test 2 — a stranger can't comment on or react to A's post
```sql
do $$
declare sid uuid;
begin
  select id into sid from sessions where user_id = 'A_ID' order by posted_at desc limit 1;
  set local role authenticated;
  perform set_config('request.jwt.claims', '{"sub":"B_ID","role":"authenticated"}', true);
  begin
    insert into comments (session_id, user_id, body) values (sid, 'B_ID', 'test');
    raise exception 'RESULT: comment was ALLOWED (wrong)';
  exception when insufficient_privilege then
    null;
  end;
  begin
    insert into reactions (session_id, user_id, kind) values (sid, 'B_ID', 'fire');
    raise exception 'RESULT: reaction was ALLOWED (wrong)';
  exception when insufficient_privilege then
    raise exception 'RESULT: comment refused, reaction refused';
  end;
end $$;
```
- [ ] Expect: `RESULT: comment refused, reaction refused`

### Test 3 — a clubmate can read and comment
Pick **C**: a rower **in A's club** (same `club_id`). Replace `C_ID`. A's newest post must be
set to **Club** or **Everyone** (the default).
```sql
do $$
declare sid uuid; s int;
begin
  select id into sid from sessions where user_id = 'A_ID' order by posted_at desc limit 1;
  set local role authenticated;
  perform set_config('request.jwt.claims', '{"sub":"C_ID","role":"authenticated"}', true);
  select count(*) into s from sessions where id = sid;
  insert into comments (session_id, user_id, body) values (sid, 'C_ID', 'test');
  raise exception 'RESULT: can read=% and the comment was accepted', s;
end $$;
```
- [ ] Expect: `RESULT: can read=1 and the comment was accepted` (nothing is saved — the error
      undoes it).

### Test 4 — following is enough too
In the app, sign in as B and follow A (if A is private, have A accept). Run **Test 1** again.
- [ ] Expect: the numbers are **greater than 0** for posts set to Following or Everyone.

## If something fails
Note the section, what you saw, and (for part 2) the exact result or error text, and send it to
Claude. Do not change policies by hand in the dashboard.

# Phase E test checklist — private accounts and follow requests

Run against the **staging** Supabase project, after both files in `docs/migrations/`
(`2026-09-23-private-accounts.sql`, then `2026-09-23-private-photos.sql`) have run.
Tick each box; anything that doesn't match "Expect" is a bug — note the step number.

## Cast

- **A** — your existing account, the one with real posts. This is the account that will go
  private and public.
- **B** — a brand-new second account, following nobody, that starts as a stranger to A.

Use two devices or two simulators so both stay signed in. A posting needs a camera, so A should
be your real account on your phone (or already have posts); B can be a simulator.

### Set up B on a second simulator (Xcode)
1. Open `Rowing Pals.xcodeproj` in Xcode.
2. In the top bar, click the device name next to the scheme, and choose **iPhone 17e** (any
   simulator other than the one A uses).
3. Press **Cmd + R**. When the app opens, sign up as B (new email) and finish onboarding.
4. Leave that simulator running. To switch device later, repeat steps 2–3.

## Part 1 — In the app

### 1. Baseline: A is public
- [ ] **B** opens **Profile** → **Find rowers**, searches A's name. Expect: A appears, no lock icon.
- [ ] **B** taps A. Expect: A's full profile — stats, PBs, posts, follower/following counts.
- [ ] **B** taps **Follow**. Expect: the button becomes **Following** at once (public = no request).
- [ ] **B** opens **Feed → Following**. Expect: A's posts appear, with photos.
- [ ] **B** opens **Rankings**. Expect: A is on the leaderboards.
- [ ] Existing follows still work: on A's phone, **Feed → Following** still shows the people A followed
      before the migration.

### 2. A goes private
- [ ] **A**: **Profile → Edit → Privacy → Profile visibility**, switch **Private account** on, tap **Done**.
      Expect: the row now reads **Private**.
- [ ] **B is already following A**, so B should still see everything. **B** pulls to refresh A's
      profile. Expect: still unlocked, still in the feed and rankings.
- [ ] **B** taps **Following** to unfollow.

### 3. Stranger view (B not following A)
- [ ] **B** opens A's profile. Expect: **"This profile is private"** card with the lock, and **no**
      stats, PBs, posts, streak, or follower/following counts.
- [ ] **B → Feed → Following and My Club**. Expect: none of A's posts.
- [ ] **B → Rankings → Volume and Test results**. Expect: A is **absent** from every board.
- [ ] **B → Find rowers** search for A. Expect: A still listed, **with a lock icon**.
- [ ] A **club-mate** test: if B joins A's club (Profile → club), A's posts must still be hidden.

### 4. Request and approve
- [ ] **B** taps **Follow** on A. Expect: **Requested** (not Following).
- [ ] **A**: **Profile**. Expect: a **Follow requests · 1** row.
- [ ] **A** taps it. Expect: B listed with **Decline** and **Accept**.
- [ ] **A** taps **Accept**. Expect: B disappears from the list.
- [ ] **B** pulls to refresh A's profile. Expect: **unlocked** — stats, PBs, posts, counts.
- [ ] **B**: A's posts appear in **Feed → Following** with photos; A appears on **Rankings**.
- [ ] **A**'s **Followers** count went up by 1; opening it lists B.

### 5. Cancel and decline
- [ ] **B** unfollows A, then **Follow** → **Requested** → tap **Requested** again. Expect: back to **Follow**;
      A's request count returns to 0.
- [ ] **B** requests again; **A** taps **Decline**. Expect: request gone. **B** refreshes: button is **Follow**
      (not Requested).

### 6. Going public approves waiting requests
- [ ] **B** requests to follow A again (A still private) → **Requested**.
- [ ] **A** switches **Private account** off. Expect: no confirmation needed.
- [ ] **B** refreshes A's profile. Expect: **Following**, unlocked. A's request count is 0.

### 7. Follow back and lists
- [ ] B follows A (from step 6). **A** opens **Profile → Followers**, taps B's row to open B's profile.
      Expect: the button reads **Follow back** (B follows A, A doesn't follow B yet). Tap it.
      Expect: **Following**.
- [ ] Tapping a name in Followers/Following opens that profile, and **✕** closes back to the tabs.
- [ ] A **blocked** rower doesn't appear in Find rowers.

## Part 2 — Prove the database enforces it (not just the app)

This is the important part: it shows the rules hold even if someone bypasses the app. In the
Supabase dashboard → **SQL Editor** → **+ New query**.

### Get the two ids
```sql
select id, display_name from profiles order by created_at desc limit 10;
```
Copy A's id and B's id. Replace `A_ID` and `B_ID` below (keep the quotes).

### Test 1 — a stranger sees nothing (set A private, make sure B does not follow A)
```sql
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"B_ID","role":"authenticated"}', true);
select
  (select count(*) from sessions     where user_id = 'A_ID') as sessions_b_can_see,
  (select count(*) from daily_totals where user_id = 'A_ID') as totals_b_can_see,
  (select count(*) from test_results where user_id = 'A_ID') as results_b_can_see,
  (select count(*) from storage.objects
     where bucket_id in ('monitors','selfies')
       and (storage.foldername(name))[1] = 'A_ID') as photos_b_can_see;
rollback;
```
- [ ] Expect: one row, **every number is 0**.

### Test 2 — an approved follower sees everything
Have A accept B's request (Part 1, step 4), then run the same script.
- [ ] Expect: counts **greater than 0** (they match A's real data).

### Test 3 — B cannot approve their own request
Make A private and B not a follower, have B send a request, then:
```sql
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"B_ID","role":"authenticated"}', true);
update follows set status = 'accepted' where follower_id = 'B_ID' and followee_id = 'A_ID';
rollback;
```
- [ ] Expect: **UPDATE 0** (no rows changed).

### Test 4 — B cannot choose an "accepted" status
With A private and no existing follow row from B:
```sql
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"B_ID","role":"authenticated"}', true);
insert into follows (follower_id, followee_id, status) values ('B_ID', 'A_ID', 'accepted');
select status from follows where follower_id = 'B_ID' and followee_id = 'A_ID';
rollback;
```
- [ ] Expect: the result says **pending**, not accepted.

`rollback;` undoes every test, so nothing here changes your data. The editor shows only the
last statement's result, which is why Test 1 is a single query and Tests 3–4 end with their result
before the `rollback;`.

## If something fails
Note the step number, what you saw, and (for Part 2) the exact result or error text, and send
it to Claude. Do not try to fix policies by hand in the dashboard.

# Coaching Phase 2 (set workouts) — test checklist

Decisions 49–52 in `docs/design/v2-decisions.md`; plan in `docs/design/coaching-build-plan.md`.
Branch `t40-coaching-phase2`. **Don't merge until every box you can tick is ticked on your phone.**
You need two accounts in the same club: **Coach** (made a coach in Phase 1, e.g. Piero) and
**Rower** (a rowing member, e.g. Mango2) — ideally on two phones, or sign out and in.

## 0. Run the coaching migration again on staging (do this first)
The file gained a section (5b); it's safe to run again.
1. Supabase dashboard → the **staging** project → **SQL Editor** → **+ New query**.
2. Open `docs/migrations/2026-10-05-coaching.sql`, select all (Cmd+A), copy (Cmd+C), paste (Cmd+V).
3. Click **Run**. Expect **Success. No rows returned**. Any red error: stop and send it to Claude.

`send-push` is already redeployed to staging with the new alert.

## 1. Install the build
1. Plug in your iPhone; in Xcode choose the **RP Dev** scheme and **your iPhone**.
2. Press **Cmd+R**.

## 2. Set a workout (Coach)
1. **Profile → Club → Coaching**. Under the header: **Rowers | Workouts**. Tap **Workouts**.
- [ ] A blue **New workout** button; with nothing set yet, a line saying so.
2. Tap **New workout**.
- [ ] Laid out like the canvas: **Title**; **Date** and **Time (optional)** side by side ("Add time");
      **Description**; **TARGET ZONE** UT2 · UT1 · AT · TR · AN; **PIECES** with **Add piece** and
      the note; **TEST DAY** card "This is a test"; **WHO IT'S FOR** Whole club · Squads · Rowers;
      "N rowers get “New workout from your coach”…"; **Set workout**.
3. Title "3 × 2,000m"; date **today**; Add time → 06:30; zone **AT**.
4. **Add piece** → Distance, **2000**, reps **3**, rest **5:00**, rate **26** to **28**, leave split
   empty → **Done**.
- [ ] The row reads "2,000m × 3" / "Rest 5:00 · rate 26–28". Tap it: same values; **Remove piece**
      works (add it back).
- [ ] Type a distance of **50**: "Enter a distance between 100 and 100,000 m."; Done is greyed.
5. Who it's for: **Rowers** → tap Rower's chip (it turns blue). The count reads "1 rower get…".
   Try **Squads** with no squads: the note points to Squads. Go back to **Rowers**.
6. **Set workout**.
- [ ] Back on Workouts: **TODAY** has the card — "<today> · 06:30" in blue, an **AT** chip,
      "3 × 2,000m", the rower's name, "Completed 0 of 1" and an empty bar.
- [ ] **Rower's phone**: an alert "New workout from your coach" / "<Coach>: 3 × 2,000m · <date>, 06:30".
- [ ] Settings → Notifications on Rower's phone has **New workouts** — "When your coach sets you a
      workout" (on). Turn it off, have Coach set another workout for Rower: no alert. Turn it back on.

## 3. Today's workout (Rower)
1. **Feed**.
- [ ] At the top: a card with a blue glow, **TODAY'S WORKOUT** and an **AT** chip, "3 × 2,000m",
      "From <Coach> · you", **Rate 26–28 · Split x:xx.x · Pieces 3 × 2,000m**, and **Log it**.
      (Split is Rower's own target from their predicted 2k; with no prediction yet it's left out.)
- [ ] A coach-only account never sees this card.
2. Tap **Log it**.
- [ ] Log opens with a glass panel over the camera: **TODAY'S WORKOUT**, "3 × 2,000m · AT",
      "Rate 26–28 · split …", and **Link this session** switched **on**.
3. Post a session: 3 main pieces of 2,000 m each (photos, or **Enter session manually** with three
   pieces labelled Main).
- [ ] On Review, the zone is already **AT**.
- [ ] Post goes through as normal.

## 4. Results (Coach)
1. Coaching → Workouts → tap the workout.
- [ ] Header "Workout"; card with the date, **AT**, title in big type, "Rower · rest 5:00 · rate
      26–28", and **1 done · 0 partly · 0 not yet**.
- [ ] **All 1 | Done | Not yet** filter; **SPLITS AGAINST TARGET** with "− faster · + slower".
- [ ] Rower's card: "Target x:xx.x /500m · rate 26–28", a green **Done** chip, three splits each
      with a green "−0.4" (faster) or red "+0.3" (slower).
- [ ] "Showing 1 of 1. Sessions are linked when a rower posts while the workout is showing."
- [ ] Back on Workouts the card reads "Completed 1 of 1" with a full **green** bar.
2. Partly: set another workout for Rower (3 × 2,000m); Rower posts only **two** 2,000 m pieces linked.
- [ ] Rower's chip reads **2 of 3**, the third split "—"; counts read 0 done · 1 partly.
3. Not linked: set another; Rower posts with **Link this session** switched **off**.
- [ ] Rower stays **Not yet**.
4. **Delete workout** at the bottom → **Delete**: it's gone from Workouts and from Rower's Feed. The
   session stays on Rower's profile.

## 5. Test day (decision 50)
1. Coach: New workout "2k test", **This is a test** on → **Test** → **2k** (the zone row disappears:
   tests are all-out). For Rower. Set workout.
- [ ] Workouts card shows a **Test** chip and "Rower · test day".
2. Rower: Feed card shows **Test**; Log it → post a 2,000 m piece (from a photo).
- [ ] On Review, the session type is already **2k test** and the zone **AN**.
- [ ] After posting, the result is on **Rankings → Test results → 2k** (with "Include on
      leaderboards" on), exactly as if you'd chosen 2k yourself.

## 6. Whole club and squads
- [ ] A **Whole club** workout reaches every rowing member (count on New workout), and appears on
      each of their Feeds; Coaching's card reads "Whole club".
- [ ] A **Squads** workout (make a squad first) reaches only its members; others don't see it.
- [ ] Two workouts today for one rower: on Log, tapping the panel's title offers both.

## 7. The database enforces it (SQL, staging)
Same as Phase 1: each test ends with a red `RESULT: …` box on purpose; nothing is changed.

### Get the ids
```sql
select id, display_name, club_id, is_coach, is_rower from profiles order by created_at desc limit 30;
select id, title, workout_date, audience from coach_workouts order by created_at desc limit 10;
```
Pick **M** a plain member who isn't a coach, **W** a workout, **R** a rower W was set for, and **X**
a member it was **not** set for (all in the same club).

### Test 1 — only coaches set workouts
```sql
do $$
begin
  set local role authenticated;
  perform set_config('request.jwt.claims', '{"sub":"M_ID","role":"authenticated"}', true);
  perform create_workout('x', current_date, null, null, 'UT2', null, '[]'::jsonb, 'club', null, null);
  raise exception 'RESULT: member set a workout (wrong)';
exception when raise_exception then
  if sqlerrm like 'RESULT:%' then raise; end if;
  raise exception 'RESULT: refused — %', sqlerrm;
end $$;
```
- [ ] Expect `RESULT: refused — Only your club's coaches can set workouts.`

### Test 2 — a rower sees only workouts set for them
```sql
do $$
begin
  set local role authenticated;
  perform set_config('request.jwt.claims', '{"sub":"X_ID","role":"authenticated"}', true);
  raise exception 'RESULT: X sees W=%, in my_workouts=%',
    (select count(*) from coach_workouts where id = 'W_ID'),
    (select count(*) from my_workouts(current_date - 30, current_date + 30) where id = 'W_ID');
end $$;
```
- [ ] Expect `RESULT: X sees W=0, in my_workouts=0` (and 1 / 1 if you use R_ID instead).

### Test 3 — a session can't be linked to someone else's workout
```sql
do $$
begin
  set local role authenticated;
  perform set_config('request.jwt.claims', '{"sub":"X_ID","role":"authenticated"}', true);
  update sessions set workout_id = 'W_ID'
  where id = (select id from sessions where user_id = 'X_ID' order by posted_at desc limit 1);
  raise exception 'RESULT: linked (wrong)';
exception when raise_exception then
  if sqlerrm like 'RESULT:%' then raise; end if;
  raise exception 'RESULT: refused — %', sqlerrm;
end $$;
```
- [ ] Expect `RESULT: refused — That workout isn't set for you.`

## Added beyond the canvas — check these
- [ ] **Personal targets** (decision 51): without a coach's split, each rower's target comes from
      their Pace Engine prediction for the zone and distance.
- [ ] **Add piece sheet** and **test picker**: needed by the canvas but not drawn.
- [ ] **Delete workout** on the results page (there's no editing; delete and set again).
- [ ] The workout's **description** on the rower's Today's workout card.
- [ ] **Several workouts on one day**: choose which on the Log screen.
- [ ] Tapping the "New workout" alert just opens the app (the workout is on the Feed on its day).

## What needs a second phone (or a second account)
- The alert (section 2) arrives on the rower's phone, not the coach's.
- Feed and Log (section 3) are seen as the rower; results (section 4) as the coach.

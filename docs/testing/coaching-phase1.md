# Coaching Phase 1 — test checklist

Decisions 34–47 in `docs/design/v2-decisions.md`; plan in `docs/design/coaching-build-plan.md`.
Branch `t39-coaching-phase1`. **Don't merge until every box you can tick is ticked on your phone.**

## 0. Run the migration on staging (do this first, before installing the build)
The new build reads columns that only exist after this runs; installed first, the feed and
profile would show errors.
1. Open the Supabase dashboard and pick the **staging** project (not production).
2. Left sidebar → **SQL Editor** → **+ New query**.
3. Open `docs/migrations/2026-10-05-coaching.sql` in Xcode or any text editor, select everything
   (Cmd+A), copy (Cmd+C), paste it into the query box (Cmd+V).
4. Click **Run** (bottom right). Expect **Success. No rows returned**.
   If you see any red error, stop and send the whole error text to Claude.
5. Safe to run again: running it a second time should also say **Success**.

## 1. Install the build on your phone
1. Plug in your iPhone. In Xcode's top bar, click the scheme name and choose **RP Dev**; click the
   device name next to it and choose **your iPhone**.
2. Press **Cmd+R**. Wait for the app to open on the phone.

## 2. Nothing else broke
- [ ] **Feed**, **Rankings** (Volume and Test results) and **Profile** load as before.
- [ ] Tap **+** (Log), take or pick a monitor photo, go on to **Review session**: the
      **Include on leaderboards** switch is **blue** when on (decision 44). Cancel out.
- [ ] **Profile → ⚙︎ Settings → Privacy Policy**: "Who can see it" now says your club's coaches see
      your training, age and bodyweight, and that coaches can't comment unless the usual rules
      already let them see the post.

## 3. Make a coach (the account that owns or co-owns your test club)
1. **Profile** tab → scroll to **Club** → **Manage your club**.
2. Under **Members**, tap **Manage** next to a member.
- [ ] A sheet opens: **Cancel · Member · Done**, their picture and name, "Senior" (or Novice) and —
      for anyone who joins from now on — "joined Oct 2026"; **Club role** as a segmented control;
      a **Coaching** card with a **Make coach** switch and its explanation; **Remove from club**.
3. Turn **Make coach** on → **Done**.
- [ ] Their row now reads "Member · Coach" (or their role · Coach).
4. Tap **Manage** on **your own row** → turn **Make coach** on → **Done**.
- [ ] Your row reads "Owner · Coach". (Owners and co-owners can coach; an admin or member sees no
      Make coach switch — check with a non-owner account if you have one.)
- [ ] **Cancel** in the sheet throws a change away: flip the switch, tap **Cancel**, reopen — unchanged.

## 4. Getting into Coaching
- [ ] **Profile → Club** now shows a blue **Coaching** button above **Manage your club**.
- [ ] As a coach who is a plain member (a second account): **Profile → Club → Your club** shows
      "You're a member · Coach" in the club card and a blue **Coaching** button inside it.
- [ ] **Your crew** has a **Coaches · N** section (everyone coaching but you, e.g. "Owner · Coach ·
      Senior" or "Coach · doesn't row"), then **Crewmates**, then the line "Coaches who don't row
      never appear in Crewmates or on any leaderboard."

## 5. The Rowers list
1. Tap **Coaching**. It opens full screen: **✕ · Coaching · squads icon**.
- [ ] Two pills: **All squads** and **Behind target**; two stat cards: **behind target** and
      **flagged**; **THIS WEEK · N ROWERS**; a card per rowing member.
- [ ] Each card: picture, name, their squads (or level) and "· Coach" for rowing coaches;
      "**x.x** / NN km this week" and sessions; a thin bar — **red** if they're behind the
      pro-rata share of their target (decision 43: nothing is due on Monday; by Wednesday two
      sevenths), white otherwise; "2k PB" and "Predicted 6:52.3 · High" (or "—" without enough
      sessions); any flags as chips.
- [ ] Coach-only accounts are **not** on the list.
- [ ] Footer: "Predictions and flags come from the Pace Engine."
2. Tap either pill.
- [ ] Sheet **Reset · Show · Done**: **Squad** list (All squads + each squad with "N rowers", tick
      on the chosen one) and **Sort by** (Behind target / Not logged / Name).
3. Choose **Name** → **Done**: the list is alphabetical and the second pill reads **Name**.
4. Choose a squad → **Done**: only its rowers show; the first pill reads the squad's name.
5. **Reset** → **Done**: back to All squads, Behind target.
- [ ] Pull down to refresh: the list reloads.
- [ ] **✕** closes Coaching back to where you opened it.

## 6. One rower
Tap a rower's card.
- [ ] Header **Rower**; big picture, name, squads; chips **Age NN** and **NN.N kg** (only if they've
      entered date of birth / weight) and **Private account** if theirs is private.
- [ ] A card per flag (red for no session in 10+ days and elevated effort, neutral for mis-tagged).
- [ ] This week: km of target (red when behind), sessions, predicted 2k with its band, and the bar.
- [ ] **WEEKLY VOLUME · 8 WEEKS**: eight bars, this week's in blue; first week's date under the
      left, "This week" under the right.
- [ ] **ZONE MIX · LAST 4 WEEKS**: one bar in five shades and a legend with percentages (or
      "No zoned erg sessions…").
- [ ] **EFFORT TREND**: "Average effort per session N.N / 10" for the last 7 days (red when
      flagged), a line over 8 weeks and a dashed 4-week average.
- [ ] **TESTS**: latest result per test with "date · NNN W · N.NN W/kg" (W/kg only when they've
      entered a weight) and a **PB** chip when it's their best. Tap one → their PB history.
- [ ] **POSTS**: a 3-wide grid of their monitor photos; tap one → the workout.
- [ ] A **private** rower who **hasn't** approved you: their post opens; reactions show but can't
      be tapped, there's no ＋, and instead of the comment box: "You can see this as their coach.
      Only people they share it with can comment or react." **View all** comments: same note.
- [ ] A public clubmate's post (or one you follow): you can react and comment as normal.

## 7. Squads
1. In Coaching, tap the **squads icon** (top right).
- [ ] **Squads**: each squad with "N rowers · names and N more", the note about squads, **New squad**.
2. **New squad** → type "Lightweights" → tick three rowers → **Save squad**.
- [ ] Back on Squads, "Lightweights · 3 rowers · …" is listed. Coaching's squad filter offers it.
3. Open it → **Select all** → **Save squad**: count updates. Rename it → **Save squad**: new name.
4. Make a second squad with the same name.
- [ ] Red message "Your club already has a squad called that."
5. Open a squad → **Delete squad** → **Delete**: it's gone.
- [ ] As the owner or a co-owner: **Profile → Club → Manage your club → Squads** opens the same screen.

## 8. Coach only (Edit profile)
1. **Profile → ⚙︎ → Edit profile**.
- [ ] Laid out like the canvas: picture with **Change photo**, **NAME**, **ACCOUNT TYPE** ("How you
      use Rowing Pals", I row / Coach only), **RANKINGS** (Gender, Level and the note), **ABOUT YOU**
      (date of birth and kg side by side, "Visible to you and your club's coaches…"), **WEEKLY
      TARGET** in km, **Save**.
- [ ] **Change photo** offers Take photo / Choose from library / Remove photo, and a new picture shows.
- [ ] Type **600** in Weekly target: "Enter a weekly target between 0 and 500 km." Type **45** → Save.
2. Choose **Coach only**.
- [ ] The **RANKINGS** section disappears. Tap **Save**.
- [ ] Back on the tabs: **no Log (+) button**, and the bar sits further in from the edges.
- [ ] **Rankings → Volume**: you're not on the board; **Test results**: your results don't count in
      "Best in your group". From another account in your club: you're not in **Crewmates** or on
      any board.
- [ ] If you're a coach, **Coaching** still works.
3. Switch back to **I row** → **Save**: the Log button is back, you're back on the boards.

## 9. Profile visibility
1. **Settings → Privacy**.
- [ ] Under the card: "Your club's coaches can always see your training, age and bodyweight."
2. Tap **Profile visibility**.
- [ ] A pushed screen (not a sheet) with **Public** ("Anyone can follow you and see your profile.")
      and **Private** ("Only followers you approve see your posts."), a tick on the current one,
      and the note ending "…Your club's coaches always see your training, age and bodyweight,
      whichever you choose."
- [ ] Tap the other option: the tick moves straight away (it's saved). Tap back to restore.

## 10. Told before joining (needs a second account not in a club)
- [ ] **Choosing a club with coaches** (Your crew → Find a club to join → pick it → the bottom
      button): a sheet "**<Club> has coaches**" with the eye icon, the explanation, each coach, the
      note, the button (e.g. **Request to join**) and **Not now**. **Not now** joins nothing.
- [ ] Continue from the sheet: it joins / requests as before.
- [ ] A club **without** coaches: no sheet.
- [ ] **Invite code** for a club with coaches: the same sheet appears before joining.
- [ ] **Invitation** to a club with coaches (Your crew → Invitations → **Join**): the same sheet first.

## 11. Signing up as a coach (needs a brand-new account)
1. Create an account, pick a club, go on to **About you**.
- [ ] "HOW WILL YOU USE ROWING PALS?" with **I row** / **I'm a coach** cards (blue ring and tick on
      the chosen one); "You can change this later in Edit profile."
2. Choose **I'm a coach**.
- [ ] Gender and Level disappear; a card says no gender or level is needed, there's no Log button,
      and Coaching is reached from Your crew once a club makes you a coach. Button reads **Start**.
3. **Start**.
- [ ] The app opens with **no Log button**.

## 12. The database enforces it (SQL, staging)
Each test pretends to be one person, then **ends on purpose with a red error whose text is the
answer** (`RESULT: …`). The error also undoes everything, so none of this changes your data. A red
box starting with `RESULT:` is success; any other error text is a problem — send it to Claude.
Same place: **SQL Editor → + New query → paste → Run**.

### Get the ids
```sql
select id, display_name, club_id, club_role, is_coach, is_rower, is_private
from profiles order by created_at desc limit 30;
```
Pick, all in the **same club**: **C** a coach (`is_coach` true) who isn't the owner; **P** a
**private** rower with at least one post whom C does **not** follow; **M** a plain member who isn't
a coach, owner or co-owner and doesn't follow P. Replace `C_ID`, `P_ID`, `M_ID` below (keep the
quotes).

### Test 1 — a coach reads a private rower's training, photos, age and weight
```sql
do $$
declare s int; ph int; ap int; dt int;
begin
  set local role authenticated;
  perform set_config('request.jwt.claims', '{"sub":"C_ID","role":"authenticated"}', true);
  select count(*) into s  from sessions where user_id = 'P_ID';
  select count(*) into ph from storage.objects
    where bucket_id = 'monitors' and (storage.foldername(name))[1] = 'P_ID';
  select count(*) into ap from athlete_private where user_id = 'P_ID';
  select count(*) into dt from daily_totals where user_id = 'P_ID';
  raise exception 'RESULT: posts=% photos=% private_row=% day_totals=%', s, ph, ap, dt;
end $$;
```
- [ ] Expect posts and photos above 0 (private_row is 1 if P entered a date of birth or weight).

### Test 2 — the same coach can't comment on or react to it (decision 40)
```sql
do $$
declare sid uuid;
begin
  select id into sid from sessions where user_id = 'P_ID' order by posted_at desc limit 1;
  set local role authenticated;
  perform set_config('request.jwt.claims', '{"sub":"C_ID","role":"authenticated"}', true);
  begin
    insert into comments (session_id, user_id, body) values (sid, 'C_ID', 'test');
    raise exception 'RESULT: comment was ALLOWED (wrong)';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into reactions (session_id, user_id, kind) values (sid, 'C_ID', 'fire');
    raise exception 'RESULT: reaction was ALLOWED (wrong)';
  exception when insufficient_privilege then
    raise exception 'RESULT: comment refused, reaction refused, read-only=%',
      (select count(*) from sessions_i_can_interact_with(array[sid])) = 0;
  end;
end $$;
```
- [ ] Expect `RESULT: comment refused, reaction refused, read-only=t`

### Test 3 — a plain clubmate still can't read the private rower
```sql
do $$
declare s int; ap int;
begin
  set local role authenticated;
  perform set_config('request.jwt.claims', '{"sub":"M_ID","role":"authenticated"}', true);
  select count(*) into s  from sessions where user_id = 'P_ID';
  select count(*) into ap from athlete_private where user_id = 'P_ID';
  raise exception 'RESULT: posts=% private_row=%', s, ap;
end $$;
```
- [ ] Expect `RESULT: posts=0 private_row=0`

### Test 4 — a plain member can't make anyone a coach, or themselves
```sql
do $$
begin
  set local role authenticated;
  perform set_config('request.jwt.claims', '{"sub":"M_ID","role":"authenticated"}', true);
  begin
    perform set_club_coach('M_ID', true);
    raise exception 'RESULT: set_club_coach was ALLOWED (wrong)';
  exception when raise_exception then
    if sqlerrm like 'RESULT:%' then raise; end if;
  end;
  begin
    update profiles set is_coach = true where id = 'M_ID';
    raise exception 'RESULT: direct update was ALLOWED (wrong)';
  exception when raise_exception then
    if sqlerrm like 'RESULT:%' then raise; end if;
    raise exception 'RESULT: both refused';
  end;
end $$;
```
- [ ] Expect `RESULT: both refused`

### Test 5 — squads: a member can't make one, a coach can
```sql
do $$
declare v uuid;
begin
  set local role authenticated;
  perform set_config('request.jwt.claims', '{"sub":"M_ID","role":"authenticated"}', true);
  begin
    perform create_squad('SQL test squad');
    raise exception 'RESULT: member created a squad (wrong)';
  exception when raise_exception then
    if sqlerrm like 'RESULT:%' then raise; end if;
  end;
  perform set_config('request.jwt.claims', '{"sub":"C_ID","role":"authenticated"}', true);
  v := create_squad('SQL test squad');
  perform set_squad_members(v, array['P_ID'::uuid, 'M_ID'::uuid]);
  raise exception 'RESULT: member refused, coach made a squad of %',
    (select count(*) from squad_members where squad_id = v);
end $$;
```
- [ ] Expect `RESULT: member refused, coach made a squad of 2`

### Test 6 — leaving the club ends coaching
```sql
do $$
begin
  set local role authenticated;
  perform set_config('request.jwt.claims', '{"sub":"C_ID","role":"authenticated"}', true);
  perform leave_club();
  raise exception 'RESULT: still coach=%, squads left=%',
    (select is_coach from profiles where id = 'C_ID'),
    (select count(*) from squad_members where user_id = 'C_ID');
end $$;
```
- [ ] Expect `RESULT: still coach=f, squads left=0`

## What needs a second phone (or a second account)
- Coach and rower at once: making someone a coach on one phone and seeing **Coaching** appear on
  theirs (it should appear within a few seconds, or on reopening the app).
- The join notice (sections 10 and 11) needs an account that isn't in a club / a new account.
- Crewmates and boards without a coach-only member (section 8) are seen from another account.
- Read-only posts (section 6) need a private rower in the club who hasn't approved the coach.

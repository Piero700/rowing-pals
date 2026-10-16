# Coach version, phase CV3 (Boats and water sessions) — test checklist

Decisions 67 and 70 in `docs/design/v2-decisions.md`; plan in `docs/design/coach-version-build-plan.md`.
Branch `t41-coach-version`. **Don't merge until every box you can tick is ticked on your phone.**
Do phase CV1's and CV2's checklists first (`docs/testing/coach-version-phase1.md`,
`coach-version-phase2.md`): this phase builds on both.

Accounts: **Coach_J** (coach only) and **Piero** (rows, same club; his side is Bow side). A second
rower helps for crews (Joe, Apple, Mango2… are already in the club).

## 0. Run the migration on staging (do this first)
1. Make sure phase CV2's `docs/migrations/2026-10-16-calendar.sql` has been run (CV2 checklist, step 0).
   This one needs its tables.
2. Supabase dashboard → the **staging** project (URL starts `gdcgqesjzmbctyafdutn`) → left sidebar →
   **SQL Editor** → **+ New query**.
3. Open `docs/migrations/2026-10-16-boats.sql` in Xcode or TextEdit, **Cmd+A**, **Cmd+C**, click into the
   query box, **Cmd+V**, click **Run**.
   - Expect **Success. No rows returned**.
   - Any red error: stop, take a screenshot and send it to Claude.
4. The alert function is already deployed to staging (Claude did this).

## 1. Install the build
1. Plug in your iPhone. In Xcode choose the **RP Dev** scheme and **your iPhone**.
2. Press **Cmd+R**.

## 2. The coach bar and + (sign in as Coach_J)
- [ ] The bar reads **Rowers · Workouts · Boats · Calendar** with the blue **+** beside it.
1. Tap **+**.
- [ ] A sheet **New session** with **Land session** (stopwatch) and **Water session** (waves), each with
      a line under it, and "Practices, races and other events are added from the Calendar."
2. Tap **Land session**.
- [ ] **New workout** opens, as before. Close it (X).

## 3. A water session and its first boat (Coach_J)
1. Tap **Boats**.
- [ ] Big title **Boats**, your picture top right, **Sessions · Saved boats**, and "No water sessions
      coming up. Tap + and choose Water session…".
2. **+** → **Water session**.
- [ ] **Water session** opens: Title, Date, Time (07:00), Meet at, The plan, **BOATS** "0 boats · 0
      rowers", **Add boat**, the card "Each rower is told their boat and seat …", and a greyed **Send**.
3. Title `3 × 2km at rate 28`, Date tomorrow, Time `07:00`, Meet at `Boathouse, 06:45`, The plan
   `4′ easy paddle between pieces`.
4. Tap **Add boat**.
- [ ] A sheet **Add a boat** with the date and time, "No saved boats yet…" and **New boat**.
5. Tap **New boat**.
- [ ] **Boat** opens: Boat name, Boat type pills **1x 2x 2− 4− 4+ 4x 8+** (4− chosen), Rigging
      **Stroke-rigged · Bow-rigged** with its line, **CREW** "Bow at the top", STROKE SIDE on the left
      and BOW SIDE on the right, the boat drawn upright with B · 2 · 3 · S, an oar on alternating sides
      (B on the right), dashed buttons "Bow seat · Bow side", "Seat 2 · Stroke side"… and **Stern**.
- [ ] Under it "CHOOSE FOR BOW SEAT · BOW SIDE" and the rowers: name, level, side, "2k pred. m:ss";
      Piero has **Fits**. (If you made tomorrow's practice in CV2 and rowers answered, only those who
      said **Available** are offered, those who said Can't are greyed with their reason, and a line
      says how many haven't answered.)
6. Name it `M1 four`. Tap **Piero**.
- [ ] Piero's name appears beside the bow seat ("Bow side"), and seat 2 is chosen next.
7. Tap **Piero** again (now for seat 2, stroke side).
- [ ] He moves to seat 2, and his button says **Usually bow side**.
8. Hold Piero's button, drag it onto **Bow seat** and let go.
- [ ] He's back at bow.
9. Fill the other seats with other rowers. Tap a filled seat → **Empty this seat**: it empties. Fill it
   again.
10. Tap **4+**.
- [ ] A **Cox** square appears at the stern, with a dashed **Cox** button. Tap **4−** again: it goes.
11. Tap **2x**.
- [ ] Rigging disappears (sculls), each seat gets two oars, and seats 3–4 are emptied. Tap **4−** and
      refill seats 3 and 4.
12. Leave **Keep in Saved boats** on and tap **Save boat**.
- [ ] Back on the water session: **M1 four** as a small upright boat with first names and **Not sent**;
      "1 boat · 4 rowers"; the button reads **Send to 4 rowers**.

## 4. Sending (Coach_J, then Piero)
1. Tap **Send to N rowers**.
- [ ] The screen closes. **Boats** shows **Upcoming** (or **Today**) with the session: date and time in
      blue, a **Water** chip, the title, "Meet at Boathouse, 06:45", the plan, and M1 four with **Sent**
      in green.
- [ ] (Piero's phone) An alert **Your boat** — "Sun 07:00 · you’re at bow in M1 four" (day and seat as
      you set them).
2. Sign in as **Piero** (or look at his phone).
- [ ] At the top of **Feed**: **YOUR BOAT · SUN 07:00** with a **4−** chip, "You’re at bow in M1 four",
      "From Coach_J · stroke-rigged · meet at Boathouse, 06:45", the boat with his seat filled in blue
      and his name in blue, the crew seat by seat (Bow, 2, 3, Stroke), and the plan.
- [ ] Tapping the alert opens the **Feed** with the card, from whichever tab was showing.

## 5. Changing a sent boat (Coach_J)
1. **Boats** → tap **M1 four** → swap two rowers → **Save boat**.
- [ ] On Boats, M1 four now says **Not sent**.
2. Tap the session's heading (date and title) → **Send to N rowers**.
- [ ] It's **Sent** again, and the rowers in it get a new alert with their seat.

## 6. Saved boats and Add a boat (Coach_J)
1. **Boats** → **Saved boats**.
- [ ] The line "Crews you put out again and again…", **M1 four** with "Used once", and **New saved boat**.
2. **New saved boat** → name `Novice four`, put two of M1 four's rowers in it plus two others → **Save
   boat**.
- [ ] It's listed with "Used 0 times".
3. **+** → **Water session**: a title, the **same day and time** as before → **Add boat**.
- [ ] Both saved boats are listed: type, name, crew stroke to bow ("Piero, Tom, Joe, Marcus"), and a line
      — "All 4 available" / "4 in the crew" (no practice to check against), or "Lucy can’t make it: swap
      them after adding" if someone said Can't.
4. Tap **M1 four**: it's added. **Add boat** again.
- [ ] **Novice four** now says "<name> is already in M1 four". Tap it anyway.
- [ ] It's added with that rower's seat left empty (dashed).
5. Open the new session's M1 four and turn **Keep in Saved boats** off → **Save boat**.
- [ ] The saved M1 four is still in Saved boats (turning it off only stops keeping it in step).
6. Open a saved boat from Saved boats → **Delete boat** → **Delete**: it leaves Saved boats; boats
   already added to sessions stay.

## 7. From the Calendar (Coach_J)
1. **Calendar** → tap a day → **Add**.
- [ ] Five options now: Practice, Land session, **Water session** ("The plan, then crew the boats from
      who’s available."), Race or regatta ("…Crew the boats when you know."), Other event.
2. Tap **Water session**: it opens with that day filled in. Give it a title and leave (back arrow).
- [ ] The day shows it: "07:00 · Water · <title>" and "No boats yet" (or "N boats crewed · N rowers ·
      sent / not sent"). Tapping it opens the session.
3. Calendar → **Who's available** → pick a session.
- [ ] Under the lists: **Plan boats for this session** and "Only available rowers are offered when you
      crew the boats." Tap it: a water session opens with the practice's date, time, title and place;
      crewing offers only the rowers who said Available. Open it again from Who's available: the same
      session opens (not a new one).
4. Open a race (Calendar → the race) → **Crew boats for this race**.
- [ ] A water session opens with the race's name, day and place; crewing offers those who said they
      can race (Can't greyed with their reason).

## 8. Not in a boat yet (Coach_J)
1. With tomorrow's practice answered **Available** by a rower who isn't in any boat of tomorrow's water
   session (planned from that practice, or at the same time):
- [ ] **Boats** → under the sessions, **NOT IN A BOAT YET** with the day, their name as a chip, and
      "Going on <weekday> but not seated in a boat."

## 9. Deleting (Coach_J)
1. Open a session → a boat → **Delete boat** → **Delete**: it leaves the session.
2. Open a session → **Delete session** → **Delete**: it leaves Boats and the Calendar, and (Piero) his
   Feed card goes.

## 10. Database checks (optional)
If you'd like to check rows behind any of this, send Claude a screenshot of **Table Editor →
water_sessions** (or say which session) and Claude will write the SQL with the ids filled in.

## What's built beyond the canvas or brief — please check you're happy with these
1. **Delete session**, **Delete boat** and deleting a saved boat (the canvas has no delete buttons).
2. **Empty this seat** at the top of the picker; a rower already in this boat shows their seat ("Bow
   seat") and choosing them for another seat moves them (whoever was there takes their old seat).
3. A line under the picker saying how many haven't answered (only rowers who said they can make it are
   offered, decision 68).
4. A water session has no Save button: it's saved when you add a boat, send, or leave it with a title.
5. A water session takes its answers from the club's practice at that time, or the practice or race it
   was planned from; Plan boats / Crew boats open the session already planned, if there is one.
6. Water sessions show on the coach's Calendar day (and count towards the month's dots).
7. The "Your boat" alert opens the Feed; the Feed card shows until the session's start time.
8. **Keep in Saved boats** is on by default for a new boat.
9. Add a boat's checks also say "<name> hasn’t said they can make it", and "N in the crew" when there's
   nothing to check against.

## Differences from the canvas — please check
1. "Lucy can’t make it: swap **them** after adding" (the canvas says "her"; the app doesn't know anyone's
   pronouns).
2. The cox is drawn in the text colour, not the canvas's purple: purple is kept for personal bests and
   avatars (one job per colour).
3. The chosen boat type uses the app's usual pill (soft blue), not a solid blue pill.
4. Someone taken out of a sent boat isn't told; their Feed card just goes. Everyone in a boat that's
   re-sent is told again.
5. The rower's Calendar doesn't show water sessions (the canvas shows boats only on the Feed).

# Shells, custom rigging, announcements, end times — test checklist

Decisions 68 (Whole day removed), 73, 74 and 75 in `docs/design/v2-decisions.md`. Branch
`t41-coach-version`. **Don't merge until every box you can tick is ticked on your phone.**

Accounts: **Coach_J** (coach only), **Piero** (rows; owner of UEA Boat Club).

## 0. Run the migration on staging (do this first)
1. Supabase dashboard → the **staging** project (URL starts `gdcgqesjzmbctyafdutn`) → **SQL Editor** →
   **+ New query**.
2. Open `docs/migrations/2026-10-17-rigging-and-announcements.sql`, **Cmd+A**, **Cmd+C**, click into the
   query box, **Cmd+V**, **Run**.
   - Expect **Success. No rows returned**. Any red error: screenshot it and send it to Claude.
3. The alert function is already deployed (Claude did this).

## 1. Install the build
In Xcode choose **RP Dev** and **your iPhone**, press **Cmd+R**.

> **Updated 2026-11-03 to match the current build.** Boats are now drawn on their side everywhere
> (decisions 86–88), so sections 2–4 and one line of section 8 were rewritten; **Draw boats** was removed.
> Section 14 covers the coach's boats in full.

## 2. Boats as rowing shells (Coach_J)
1. **Boats** → **Saved boats** (or a session's boats).
- [ ] Each boat is a full-width card with the boat **lying on its side**: **‹ Stern** at the left, **Bow ›**
      at the right, wing riggers and oars with spoon blades, first names under the seats.
- [ ] In a stroke-rigged four the stroke's oar is **above** the boat (stroke side), then they alternate.
2. Open a boat.
- [ ] The crew card shows the boat on its side with a button under each seat, and the line "Stroke side’s
      oars are above the boat, bow side’s below."

## 3. Custom rigging (Coach_J)
1. In a four, tap **Rigging → Custom**.
- [ ] The line under it reads "Custom: tap ⇄ beside an oar…", and a small round **⇄** appears beside
      each oar.
2. Tap ⇄ on seat 3, then on seat 2 (of a stroke-rigged four), so stroke and bow are on stroke side and
   3 and 2 on bow side (a bucket rig).
- [ ] Each oar moves to the other side of the boat (above ↔ below) as you tap.
3. **Save boat**, then open it again.
- [ ] Still **Custom**, with the same sides. On the Boats tab its card says **Custom** and shows the
      bucket rig.
4. (A sent boat) change its rigging and save.
- [ ] It goes back to **Not sent**.
5. Switch Custom → **Stroke-rigged**: the ⇄ buttons go and the oars alternate again.

## 4. Draw boats — removed
Nothing to test. **Draw boats** was taken out of Settings (decision 88); section 14 step 6 checks it's gone.

## 5. Announcements (Coach_J, then Piero)
1. Coach_J: tap **+**.
- [ ] The sheet is titled **New** with **Land session**, **Water session**, **Announcement**, **Challenge**
      and **Erg event**.
2. **Announcement**.
- [ ] **New announcement**: Heading, Message, **On the Feed for: 24 hours · 3 days · 1 week · Until…**
      (24 hours chosen), "Comes off the Feed <day>, <time>.", **Send an alert** (on), **Post announcement**
      (greyed until there's a heading), "Every rower in your club sees it on their Feed."
3. Tap **Until…**: a date and time appear; the line updates. Tap **24 hours** again.
4. Heading `Kit order closes Friday`, a message → **Post announcement**.
- [ ] (Piero's phone) An alert **New announcement** — "Kit order closes Friday". Tapping it opens the **Feed**.
5. Piero: **Feed**.
- [ ] At the top: a card with a megaphone, **Kit order closes Friday** and "Coach_J · today", folded.
- [ ] Tap it: the message opens with "On the Feed until <day>, <time>" — and **Edit** (Piero owns the
      club). Tap again: it folds away.
6. Coach_J: **Calendar**.
- [ ] Under the month: **ANNOUNCEMENTS** "1 on rowers’ Feeds", the row "Kit order closes Friday ·
      Coach_J · posted <day> · until <day, time>", and "Tap one to change it or take it down."
7. Tap it → change the heading → **Save changes**.
- [ ] The Calendar and Piero's Feed show the new heading.
8. Piero (owner): open the card → **Edit** → change the message → **Save changes**: it saves.
9. Coach_J: Calendar → the announcement → **Delete announcement** → **Delete**.
- [ ] It leaves the Calendar list and Piero's Feed.
10. Post one for **24 hours** and check the next day.
- [ ] It's gone from the Feed after 24 hours, and shows dimmed as "ended" in the Calendar for two weeks.
11. (Optional) A rower who isn't a coach, owner or co-owner opens a card: **no Edit** button.

## 6. Practice end times (Coach_J)
1. **Calendar → Add → Practice**.
- [ ] Starts **06:30**, Ends **08:30**.
2. Change **Starts** to 17:15.
- [ ] **Ends** moves to **19:15** by itself.
3. Try to set **Ends** earlier than the start.
- [ ] The picker won't go earlier than a minute after the start.
4. Start at 22:30.
- [ ] Ends at **23:59** (the same day).

## 7. No Whole day (Piero)
1. **Calendar**.
- [ ] Each day card shows the date and a short summary ("Not answered", "Both sessions"…) — **no Whole day**
      label or control; each session has its own **Available · Can't**.

## What's built beyond the design — please check
1. Anyone allowed to edit announcements (coaches, the owner, co-owners) gets **Edit** on the open card
   in their Feed; that's how an owner who doesn't coach can edit or delete one (their app has no
   coach Calendar).
2. Ended announcements stay in the coach's Calendar for two weeks, dimmed.
3. The Feed's announcements start folded; the design showed the first one open as an example.
4. ~~**Draw boats** is kept on each phone, like Appearance.~~ (Draw boats was removed, decision 88.)
5. The alert's text is "New announcement" with the heading as the message.

## 8. A tidier Feed (decision 76)
1. Coach_J: **+** → **Water session** → **Add boat** → **New boat** → type **1x** → put **Piero** in it →
   **Save boat** → **Send to 1 rower**.
2. Piero: **Feed**.
- [ ] **Your boat** shows the single **lying on its side**, bow to the right, Piero's seat in blue — with
      no name beside it, no Bow / Stern labels and no seat list.
- [ ] Coach_J opening the same boat sees it on its side too, with Piero's name under the seat.
3. Piero: scroll to any post.
- [ ] One row under the caption: the comments button (just the number), then the reactions, then
      share at the far right. No separate reactions row.
- [ ] Tapping the number opens the comments; tapping a reaction still toggles it.
- [ ] With lots of different reactions on a post, the reactions slide sideways instead of wrapping.

## 9. A coxed quad (decision 77)
0. Run `docs/migrations/2026-10-18-coxed-quad.sql` on staging first (same steps as step 0 at the top).
1. Coach_J: **Boats** → **Saved boats** → **New saved boat**.
- [ ] **Boat type** is one row: **1x 2x 2− 4− 4+ 4x 4x+ 8+**, with 8+ cut off at the right edge. Swipe the
      row left: it slides and 8+ comes into view. Nothing wraps onto a second line.
2. Tap **4x+**.
- [ ] **Rigging** disappears, each seat has two oars, and a **Cox** square sits at the stern with a dashed
      **Cox** button.
3. Name it `Novice quad`, fill the four seats and the cox → **Save boat**.
- [ ] It saves (no red error) and its tile on Saved boats says **4x+** and **Sculls**, with the cox at the stern.
4. Add it to a water session and **Send**: the cox's alert says "you're coxing", a sculler's says their seat.

## 10. Coxes (decision 78)
0. Run `docs/migrations/2026-10-18-cox-side.sql` on staging first (same steps as step 0 at the top).
1. A rower: **Settings → Edit profile → Side**.
- [ ] Four choices: **Stroke side · Bow side · Both · Cox**, and the line "…or Cox if you cox." Pick **Cox** → **Save**: it saves.
2. Coach_J: a boat with a cox seat (4+, 4x+ or 8+) → tap the **Cox** seat.
- [ ] The cox is at the top of the list with **Fits**; everyone else follows.
3. Tap a rowing seat instead.
- [ ] The cox is in the list with a grey **Cox** tag (no Fits). Choose them: under their name in the boat it says **Cox**.

## 11. Water sessions for rowers (decision 79)
0. Run `docs/migrations/2026-10-18-water-session-ends.sql` on staging first (same steps as step 0 at the top).
   Then install the new build (**RP Dev**, your iPhone, **Cmd+R**).
1. Coach_J: **+** → **Water session**.
- [ ] Under **Date** there's **Starts 07:00 · Ends 09:00**. Change Starts to 17:15: Ends moves to **19:15**. Ends
      won't go earlier than the start.
2. Make two water sessions for **today** (one earlier, one later) and one for **tomorrow**, each with a boat that
   has Piero in it → **Send** each.
3. Piero: **Feed**.
- [ ] Only **today's** boats show, one card each. After the earlier one's **end time**, its card goes. After the
      last of today's ends, **tomorrow's** appears.
4. Piero: **Calendar** (This week / Next week).
- [ ] Each water session shows on its day: start and end time, the title, "You're at … in <boat>" in blue, and a
      **Water** chip. Tap one: **Water session** opens, read-only, with the times, meet at, set by, the plan and
      **Your boat** with your seat in blue.
5. Piero (owner, and a coach): **Settings → Boats**.
- [ ] **Water sessions in Calendar: Mine · Whole club** (Whole club chosen). With **Whole club**, the Calendar shows
      every water session in the club ("3 boats", "No boats yet" for ones you're not in); the page lists
      **Other boats**. Switch to **Mine**: only yours.
- [ ] A rower who isn't a coach, owner, co-owner or admin doesn't see that setting and sees only their own.
6. Piero: switch to **coaching**. Have Coach_J send a boat with Piero in it, then tap the **Your boat** alert.
- [ ] No crash. The app switches to the rowing version and shows the **Feed** with the boat.

## 12. Your boat on its side; Save on a water session (decisions 82, 83)
1. Coach_J: put Piero in an **8+** (any seat in the middle) and a **4−** for today, and **Send**.
2. Piero: **Feed**.
- [ ] The eight lies on its side like the single: ‹ STERN left, BOW › right, names under the seats, Piero's
      seat filled blue with his name in blue. It opens with his seat in view; swipe it to see the rest; the edge
      fades where there's more and the thin bar moves as you swipe.
- [ ] The four fits the card: nothing to scroll. A single still shows as before (no names).
3. Coach_J: open a water session.
- [ ] Under The plan: **✓ Saved** (greyed). Change Ends: it becomes **Save changes**; tap it: back to **✓ Saved**.

## 13. Feed boats drawn like a real boat (decision 86)
1. Coach_J: send a boat with Piero in it for today (an **8+** shows it best); also a **1x** if you have one.
2. Piero: **Feed**.
- [ ] Each oar leans **towards the bow** (right), with a squared **spoon blade** at the end, a **wing rigger**
      from the hull to the pin, and the handle reaching in over the boat — as on the canvas board
      *Feed boats, more realistic*, column **A**.
- [ ] Stroke-side oars are above the boat, bow side below; in a double or quad every seat has one each side.
- [ ] Seats keep their numbers (S … B, the cox's square C); Piero's is blue. No blade covers a name.
- [ ] The single is drawn the same way (one seat in blue, an oar each side), with nothing cut off at the top or bottom.
- [ ] Light mode: the hull, riggers and blades are all clearly visible.

## 14. Coach boats on their side, boat colours (decisions 87, 88)
Before this section: run `docs/migrations/2026-10-18-boat-colours.sql` on staging.
1. Coach_J: **Boats** tab → **Saved boats**.
- [ ] Each saved boat is a full-width card: name, type chip, rigging, "Used n times", and the boat on its side with
      first names under the seats. A four fits; an eight scrolls sideways.
2. Open a saved **8+**.
- [ ] Under Rigging there's **Colour**: a slashed circle (None, ringed in blue), colour dots, and at the end Apple's
      colour picker. Swipe the row to see them all.
- [ ] Tap **Red**: the boat below turns red straight away. Tap the picker, choose any colour: the boat takes it and the
      picker gets the blue ring. Tap None: back to the plain boat.
- [ ] **Crew**: the boat is on its side with a button under each seat (first name and side, or "Usually bow side").
      An empty seat is dashed blue; the boat scrolls so the seat being chosen is in view.
- [ ] Tap a seat's circle or its button, then a rower in the list: they go in, and the next empty seat is chosen and
      scrolled to. Hold a name and drag it onto another seat: the two swap.
- [ ] Rigging → **Custom**: a ⇄ appears beside each oar; tap one: that oar moves to the other side of the boat.
3. Choose a colour, **Save boat**.
- [ ] The Saved boats card shows the boat in that colour.
4. Open a water session → **Add boat** → pick that saved boat.
- [ ] It comes in with its colour. **Send**, then change only its colour and save: it still says **Sent**.
5. Piero (in that boat): **Feed** and **Calendar** → the session.
- [ ] The boat is in the coach's colour on the Feed card and on the session page.
6. Settings → **Boats**.
- [ ] No **Draw boats** any more. Owners, co-owners, admins and coaches who row still see **Water sessions in
      Calendar**; other rowers don't see a Boats group at all.
- [ ] Light mode: coloured boats, riggers, blades and names all clear.

## 15. Rank-change alerts (decision 89)
Before this section: run `docs/migrations/2026-10-18-rank-change-alerts.sql` on staging (pg_cron on, as for practice
reminders). The real alert comes on Mondays at 08:00; the steps below send it now.
1. On your phone: Settings → **Notifications**.
- [ ] A **Rank changes** switch, on, under Practice reminders: "Mondays, when your place in last week's metres moved".
2. You need two or more rowers of the same gender and level in the club with erg metres **last week** (Monday–Sunday),
   on the leaderboards. If last week's are already there, skip to 3.
3. Supabase → **SQL Editor** → New query → paste `select queue_rank_change_alerts(true);` → **Run**.
- [ ] Each rower whose place last week differs from the week before gets "Last week's metres": "You finished 2nd of
      3 senior men last week with 12,000m, up 1 place." (or "down …"; no "up/down" if they didn't row the week before).
- [ ] Tapping it opens **Rankings**.
4. Run the same line again.
- [ ] Nothing new arrives: it's once a week.
5. Turn **Rank changes** off on one account. In the SQL Editor clear this week's alerts and send them again:
   `delete from rank_changes where week_start = (current_date - extract(isodow from current_date)::int - 6);`
   then `select queue_rank_change_alerts(true);`.
- [ ] That account gets nothing; the others get theirs again.

## 16. Crew tagging (decision 90)
Before this section: run `docs/migrations/2026-10-18-crew-tags.sql` on staging.
1. Piero: **+** → log a session (manual is fine) → on Review session, under Caption, **Trained with**.
- [ ] It reads "Tag the clubmates you trained with" with **Add**. Tap it: a sheet of your clubmates who row (no coach-only
      accounts, not you), with a search box.
- [ ] Tick two people, **Done**: the row shows their names and **Edit**. **Post session**.
2. **Feed**.
- [ ] Under the caption: "with Sam and Joe" (their first names). Tap a name: their profile opens.
3. Open the post.
- [ ] The same line, every name tapped opens a profile; **Change who you trained with** under it. Untick one, Done: the
      line updates here and on the Feed.
4. Sign in as one of the tagged rowers and open the post.
- [ ] **Remove me from this post**; tap it: their name goes from the line (and from the Feed card).
5. Someone who can't see the post (not following, not in the club, for a Following-only post).
- [ ] They don't see the post or its tags anywhere.

## 17. Challenges and erg events (decision 91)
Before this section: run `docs/migrations/2026-10-18-challenges-and-erg-events.sql` on staging.
1. Piero (owner): **Rankings** → the third option, **Challenges**.
- [ ] **New challenge** and **New erg event** buttons; "No challenges yet…" under them.
2. **New challenge** → Personal target, Name "100km this month", Metres each `100000`, Starts today, Ends in a month →
   **Set challenge**.
- [ ] It's under **On now** with "You · …m of 100,000m" and a blue bar. The **Feed** has a card for it too.
- [ ] Open it: your card, then every rower with a bar, "N of M done". Log a session: your metres go up.
3. New challenge → **Club total**, `500000` metres.
- [ ] Its page: the club's bar, "Your share", and **Who's rowed it**, most first.
4. New challenge → **Squad vs squad**, tick two squads (make them in Squads first if you have none).
- [ ] Its page: squads ranked on metres per rower, each with its total; tap one: its rowers. Yours is in blue.
5. **New erg event**: "Club 2k day", Distance `2000`, starting now, ending in three hours → **Set event**.
- [ ] Rankings and the Feed show it ("Erg event · On until …", **Log your 2k**).
6. Log a **photographed 2k** (or type 2000m on a monitor photo session) and go to the post screen.
- [ ] **Count for Club 2k day** is there and on. Post. Open the event: you're on the board with your time and split.
- [ ] A manual entry says it can't count; a 1,999m piece says to make a 2k your main piece.
7. Coach_J (coach version): **+**.
- [ ] **Challenge** and **Erg event** are there. The **Calendar** shows "Challenges and erg events" with the ones on now
      and coming up; tapping one opens it, with **Edit**.
8. A rower who isn't a coach, owner, co-owner or admin.
- [ ] No New buttons and no Edit; they see everything else.
9. **Edit** a challenge → **Delete challenge** → Delete.
- [ ] It goes from Rankings, the Feed and the Calendar.

## 18. Season Wrapped (decision 92)
Before this section: run `docs/migrations/2026-10-18-season-wrapped.sql` on staging. For terms: Coach_J → Calendar →
the club's terms (as for attendance totals) — add one that started a few weeks ago.
1. Piero: **Profile** → **Season Wrapped** (under Consistency / Recent activity).
- [ ] It opens on the term going on now, "… so far", with the term's days. Swipe: six pages — Your season, Totals,
      Streaks, Personal bests, Club and crew, Training mix — the numbers matching your sessions.
- [ ] **Share this page** opens the share sheet with a tall image of that page; save it to Photos and look.
2. Tap the season at the top.
- [ ] The club's terms that have begun, latest first, and **Your dates…**; choose dates: the pages follow.
3. A rower with no sessions in the dates.
- [ ] One page: "Nothing logged in … yet".
4. Make a term that ended yesterday (Coach_J), then open Piero's **Feed**.
- [ ] "Your … Wrapped is ready" card; tapping opens that term's Wrapped.

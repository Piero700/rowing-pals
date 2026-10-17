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

## 2. Boats as rowing shells (Coach_J)
1. **Boats** → **Saved boats** (or a session's boats).
- [ ] Each boat is a long, narrow shell pointed at both ends, with a small bow ball, wing riggers and oars
      with spoon blades. **STERN** is written above it and **BOW** below; the stroke seat (S) is at the top.
- [ ] In a stroke-rigged four the stroke's oar is on the **right** (stroke side), then they alternate.
2. Open a boat.
- [ ] The crew card reads **BOW SIDE** on the left and **STROKE SIDE** on the right, Stern at the top,
      Bow at the bottom; the header says "Stern at the top · change in Settings".

## 3. Custom rigging (Coach_J)
1. In a four, tap **Rigging → Custom**.
- [ ] The line under it reads "Custom: tap ⇄ beside an oar…", and a small round **⇄** appears above
      each oar.
2. Tap ⇄ on seat 3, then on seat 2 (of a stroke-rigged four), so stroke and bow are on stroke side and
   3 and 2 on bow side (a bucket rig).
- [ ] Each oar, and the rower's name with it, moves to the other side as you tap.
3. **Save boat**, then open it again.
- [ ] Still **Custom**, with the same sides. On the Boats tab its tile says **Custom** and shows the
      bucket rig.
4. (A sent boat) change its rigging and save.
- [ ] It goes back to **Not sent**.
5. Switch Custom → **Stroke-rigged**: the ⇄ buttons go and the oars alternate again.

## 4. Draw boats (any account)
1. **Settings** → **BOATS → Draw boats**.
- [ ] **Stern at the top · Bow at the top** with a small four under it, and the line "Just for you…".
2. Tap **Bow at the top**.
- [ ] The preview turns round (BOW at the top) and stroke side moves to the left.
- [ ] Boats tab, crewing and (Piero) the Feed's **Your boat** card are all drawn bow at the top.
3. Set it back to **Stern at the top**.
- [ ] (Piero) The Feed card lists the crew in the drawing's order: Stroke first with the stern at the top.

## 5. Announcements (Coach_J, then Piero)
1. Coach_J: tap **+**.
- [ ] The sheet is titled **New** with **Land session**, **Water session** and **Announcement**.
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
4. **Draw boats** is kept on each phone, like Appearance.
5. The alert's text is "New announcement" with the heading as the message.

## 8. A tidier Feed (decision 76)
1. Coach_J: **+** → **Water session** → **Add boat** → **New boat** → type **1x** → put **Piero** in it →
   **Save boat** → **Send to 1 rower**.
2. Piero: **Feed**.
- [ ] **Your boat** shows the single **lying on its side**, bow to the right, Piero's seat in blue — with
      no name beside it, no Bow / Stern labels and no seat list.
- [ ] Coach_J opening the same boat still sees it upright with STERN / BOW and Piero's name.
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

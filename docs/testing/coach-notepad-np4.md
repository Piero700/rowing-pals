# Coach notepad, phase NP4 (the Notebook and the rower's card) — test checklist

Decision 96 in `docs/design/v2-decisions.md`; plan in `docs/design/coach-notepad-build-plan.md`; boards
`docs/design/v4/CoachNotebook.dc.html`, `CoachNotebookRower.dc.html`, `RowerCoachScores.dc.html`,
`RowerCoachScoresPosted.dc.html`. Branch `t42-coach-notepad`. Test it after NP3's checklist.

Accounts: **Coach_J** (coach) and **Piero** (rows). The Notebook only shows workouts **whose day is over**,
so do this a day after the NP3 tests (or set a workout for **yesterday** in New workout, put scores on its
notepad and have Piero post one).

## 0. Run the NP4 migration on the Dev project (do this first)
The Notebook works without it; only the rower's Feed card needs it.
1. Open **supabase.com** → sign in → click the **Dev** project.
2. Left sidebar → **SQL Editor** → **+ New query**.
3. In Finder open `docs/migrations/2026-11-05-coach-notepad-np4.sql`, press **Cmd+A**, **Cmd+C**; click into
   the query box and press **Cmd+V**.
4. Click **Run**. Expect **Success. No rows returned**. Any red error: screenshot it and send it to Claude.
5. **Before the App Store build:** run it on the production project too.

## 1. The way in (Coach_J)
**Workouts** tab → scroll to **PAST**.
- [ ] Beside the "PAST" heading, on the right: **Notebook ›** in blue. It opens the Notebook.

## 2. The Notebook
- [ ] It opens on the **newest** past workout. Top right: **All squads ⌄**. Under the header: **Splits |
      Against target**.
- [ ] The page card: **‹** and **›** round buttons, the date and time, the title, and a line like
      "AT · rate 26–28" (with "target 1:42.0" when the workout set a split). A test says "Test · results
      on the club board".
- [ ] Columns **Rower · 1 · 2 · 3 · Avg** (one per piece); each rower's splits, their average in bold,
      "–" for a piece not in, "out" for sat out; a **Squad** row with the averages at the bottom.
- [ ] A rower who posted shows their own splits; where the coach typed or scanned one, that wins.
- [ ] Under the card: the page's **Notes** (if any), "N posted · N you noted · N sat out", **Edit page**
      (opens that notepad), the page dots and "Page n of N · swipe to turn the page · tap a name…".
1. Tap **‹** and **›**, then swipe the card sideways left and right.
   - [ ] Each turns one page; ‹ greys out on the oldest, › on the newest; the dots follow.
2. Tap **Against target**.
   - [ ] Each split becomes "+1.5" / "−0.4" against that rower's target: **green** faster, **red** slower.
         A rower with no target (no prediction yet, and no split set on the workout) shows "–".
3. Tap **All squads ⌄** → pick a squad.
   - [ ] Only that squad's rowers show, and only workouts they were in; pick **All squads** to go back.
4. A test page (from NP3's 2k):
   - [ ] Columns **Time · Split**; "not yet" for anyone without a result.

## 3. One rower's line
Tap a name on a page.
- [ ] The title is their full name. A card: "In the notebook", their squads · "last N pages", then
      **N of N sessions**, **avg vs target** (green/red, or "–"), **fastest piece**.
- [ ] **Page by page**, newest first: title (today's has "· today"), date · zone, their pieces
      "1:43.4 · 1:43.5 · –", their average and how far off target. A test line shows its time and
      "from their post" / "you noted".
- [ ] Tapping a line opens that notepad. The note at the bottom adds "Today's session is still being
      written." when today's workout is in the list.

## 4. The rower's Feed card (Piero)
On Coach_J's phone, note a score for Piero on a workout (today's or the last 3 days), then sign in as
**Piero** on another phone (or sign out and in) → **Feed**.
- [ ] Near the top: a card **"Your coach noted your scores"** with "Thu 5 Nov · 4 x 500m · erg N" (erg only
      once the coach set an erg order), and a tile per piece: the coach's split, "–" for pieces not noted.
- [ ] If Piero hasn't posted that workout: "Your coach's numbers don't count towards your volume,
      pieces or PBs. Log the session yourself to count it." and a blue **+ Log your session**.
1. Tap **Log your session**.
   - [ ] The normal Log flow opens for that workout, with **nothing** filled in from the coach.
2. Post it (with **Link this session** on), go back to the Feed.
   - [ ] The card stays, without the button: "✓ You posted this session · your average 1:4x.x".
- [ ] Piero can't see anything else from the notepad anywhere: no text, tables, Notes or other rowers.
- [ ] The card is gone 4 days after the workout, and never shows for a workout where the coach only
      marked Piero "sat out".

## 5. Nothing counts
- [ ] Piero's Profile volume, sessions, PBs and Rankings are unchanged by anything the coach noted.

## 6. Light mode
- [ ] Settings → Appearance → Light: the Notebook, a rower's line and Piero's Feed card read clearly.

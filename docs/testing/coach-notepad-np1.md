# Coach notepad, phase NP1 — test checklist

Decision 96 in `docs/design/v2-decisions.md`; plan in `docs/design/coach-notepad-build-plan.md`. Branch
`t42-coach-notepad`. **Don't merge until every box you can tick is ticked on your phone.**

Accounts: **Coach_J** (coach only), **Piero** (rows; owner of UEA Boat Club), and a **second coach** in the
same club if you have one (for section 8). You need a workout set for **today** with pieces, e.g.
**3 × 2,000m** for a squad Piero is in, and one with a **time piece** (e.g. 2 × 10:00).

## 0. Run the migration on staging (do this first)
1. Supabase dashboard → the **staging** project → **SQL Editor** → **+ New query**.
2. Open `docs/migrations/2026-11-05-coach-notepad.sql`, **Cmd+A**, **Cmd+C**, click into the query box,
   **Cmd+V**, **Run**.
   - Expect **Success. No rows returned**. Any red error: screenshot it and send it to Claude.
3. Running it a second time should also succeed (it's safe to run again).

## 1. Install the build
In Xcode choose **RP Dev** and **your iPhone**, press **Cmd+R**.
- [ ] It builds. If Xcode shows errors, copy them to Claude: this phase was written without a Mac, so
      the first build is the first time the Swift has been compiled.

## 2. Ways in (Coach_J)
- [ ] **Workouts** tab: today's workout has an **Open notepad** button inside its card, under the
      Completed bar; upcoming and past ones don't.
- [ ] Tapping the card still opens the workout's results; tapping **Open notepad** opens the notepad.
- [ ] On the workout's results screen there's a **pencil** top right; it opens the same notepad.
- [ ] **Calendar** tab → today: the workout's row has a **pencil** on the right that opens the notepad;
      tapping the rest of the row still opens the results.
- [ ] Every one of these swipes back from the left edge.

## 3. The page
- [ ] Under the header: the workout's title, then "Tue 4 Nov · 17:30 · Senior men · rate 26–28" (or
      whatever yours is).
- [ ] **Scores** card: one row per rower the workout is for, numbered 1, 2, 3…, short names ("Ollie H."),
      and one column per rep (1, 2, 3).
- [ ] A rower who already posted the session linked to this workout shows their splits with a small
      **blue dot**.
- [ ] Below: **Add text**, **Add table**, then **Notes** and the line "Only your club’s coaches see this
      page…".
- [ ] Every number lines up in its column (tabular figures).

## 4. Typing scores
1. Tap Ollie's box under **2**.
- [ ] The box gets a blue outline, the decimal keypad opens, and a glass bar sits above it: "Ollie
      Hart · piece 2", **Split | Time**, the number box, **Rate**, **Sat out**, **Next · (next rower)**.
2. Type **1 4 4 . 6**.
- [ ] The number box reads **1:44.6** as you type (the colon goes in by itself), and the box in the table
      shows 1:44.6 too.
3. Tap **Rate**, type **27**, tap **Next**.
- [ ] Ollie's box keeps 1:44.6; the outline moves down to the next rower on piece 2 and the keypad stays
      open.
4. Switch to **Time** and type **6 5 8 . 4**.
- [ ] Under it: "= 1:44.6 /500m". **Next** saves 1:44.6.
5. On the last rower of piece 2, tap **Next**.
- [ ] It jumps to the first **empty** box of piece 3.
6. On a rower, tap **Sat out**.
- [ ] The box reads **out**; later **Next**s on that piece skip them.
7. Tap a box you filled.
- [ ] The line under the name reads "On the page: 1:44.6. Type to change it." and a **Clear** button
      shows. **Clear** empties it (or puts back their own post, with the dot).
8. Tap a box with a blue dot.
- [ ] "From their own post: …. Yours changes only this page." Type a different split, **Next**: the
      box shows yours, without the dot.
9. Type **9 9** (0:99 isn't a time) or **5** (0:05).
- [ ] The line turns red ("That isn’t a split a rower could hold.") and **Next** says so instead of saving.
10. The workout with a **time piece**: tap a box.
- [ ] The choice reads **Split | Metres**; typing **2830** in Metres on a 10:00 piece shows "= 1:46.0 /500m".
11. Tap the **chevron** in the bar.
- [ ] The bar and keypad go away.

## 5. Erg order
1. Tap the **sort** button top right.
- [ ] A sheet lists the rowers with handles. Drag one to the top, **Done**.
- [ ] The Scores table follows the new order, and **Next** walks down it.
2. Leave the notepad and open it again.
- [ ] The order is kept.

## 6. Text, tables and Notes
1. **Add text**, write two lines.
2. **Add table**.
- [ ] A table named "Table" with headings **Rower · Technique · Next time** and two empty rows.
3. Rename it, fill a box, **+ Row**, **+ Column** twice.
- [ ] **+ Column** greys out at five columns; the columns always share the card's width equally.
4. Write in **Notes**.
5. Leave the notepad (back), open it again.
- [ ] Everything you wrote is still there.
6. Tap **✕** on the text box and on the table.
- [ ] Each goes; leaving and coming back, they stay gone.

## 7. Nothing counts (Piero)
After Coach_J has typed scores for Piero:
- [ ] Piero's **Profile** weekly volume, sessions and PBs haven't changed.
- [ ] **Rankings** (Volume and Test results) haven't changed.
- [ ] Piero's Feed and posts show nothing from the notepad.

## 8. Two coaches (if you have a second coach account)
- [ ] The second coach sees the same scores, text, tables, Notes and erg order, and can change them.
- [ ] A rower account can't open a notepad anywhere (there's no way in from the rower app).

## 9. Light mode
- [ ] Settings → Appearance → Light: the notepad, the entry bar and the erg-order sheet all read clearly.

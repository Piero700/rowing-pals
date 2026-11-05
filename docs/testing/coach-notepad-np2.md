# Coach notepad, phase NP2 (scanning a monitor) — test checklist

Decision 96 in `docs/design/v2-decisions.md`; plan in `docs/design/coach-notepad-build-plan.md`; board
`docs/design/v4/CoachNotepadScan.dc.html`. Branch `t42-coach-notepad`. **No migration this time:** a scan
saves into the `coach_notepad_scores` table NP1 already made, with `source = scanned`.

Accounts: **Coach_J** (coach) and **Piero** (rows). You need a workout set for **today** with **several
reps**, e.g. **8 × 500m** or **20 × 500m**, for a squad Piero is in, and a monitor you can row on (or a
results screen still showing from an earlier interval workout).

## 0. The NP1 fixes from your last test
In Xcode choose **RP Dev** and **your iPhone**, press **Cmd+R**. Sign in as **Coach_J**.
1. **Calendar** tab → scroll to today's land sessions.
   - [ ] "Land session · …" starts at the card's left edge, with no gap before it.
2. **Workouts** → **Open notepad** → **Add table**, then tap **+ Row** five times quickly, then
   **+ Column** twice.
   - [ ] Each tap adds its row or column straight away, with no pause.
3. Type a long sentence in **Notes**, then in a text box (**Add text**), then in a table box.
   - [ ] The letters appear as fast as you type, in all three.

## 1. The camera button
**Workouts** → today's interval workout → **Open notepad**.
- [ ] Every name in the Scores table has a round **camera** button between the name and the boxes.
- [ ] The line under the table ends "· the camera reads their monitor".

## 2. Scan one screen
1. Tap the camera by **Piero**.
   - [ ] The title reads "Piero · (the workout's name)". Top left: a **Screen 1** chip; top right:
         "0 of N read" (N = the workout's reps).
   - [ ] The camera picture shows inside a rounded panel with a white frame drawn in it, and under it:
         "Fit the monitor's results inside the frame. Only the numbers are kept: the photo is deleted
         once it's read."
2. On the monitor, open the workout's results (**Menu → Memory → the workout**, or the screen that
   shows straight after rowing), with the first pieces on screen. Fit the table inside the white frame
   and tap the round **shutter**.
   - [ ] After a second or two: a blue banner "Read from screen 1. The photo has been deleted, only these
         numbers are kept.", then a table **# · Time · Split · Metres · Rate** with one row per piece on
         the monitor's screen, all highlighted.
   - [ ] Check every number against the monitor. **Screenshot any that's wrong** and send it to Claude
         with a photo of the monitor. A "–" (not read) is fine: you can type that one later.
   - [ ] The top right reads "k of N read" and the line under the table says "Highlighted rows are new.
         … pieces still to read."
3. Open **Photos** on the phone.
   - [ ] No photo of the monitor has been added.

## 3. Scan the next screen (the joining)
1. Back in the app, tap **Scan the next screen**.
   - [ ] The chips read **Screen 1** (grey) **Screen 2** (blue), the frame label reads
         "MONITOR · NEXT PAGE OF RESULTS", and **Back to list** sits left of the shutter.
2. Tap **Back to list**.
   - [ ] You're back on the pieces from screen 1, nothing lost. Tap **Scan the next screen** again.
3. On the monitor, scroll down so the next pieces show, **leaving two or three of the last ones still on
   screen** (overlap is the point of this test). Take the photo.
   - [ ] Only the new pieces are highlighted, and the line under the table says "Pieces a–b were on both
         screens, so they're kept once." — the pieces on both photos appear once, not twice.
   - [ ] The pieces are numbered 1, 2, 3 … in order with none missing or repeated (check against the
         monitor).
4. Keep going until the count reads "N of N read" in **green**.
   - [ ] The line says "All N pieces are in. Tap a number on the page to fix it." and **Scan the next
         screen** has gone.
5. Also try one photo with **no overlap** (scroll the monitor exactly one page).
   - [ ] The pieces follow on with no overlap line, numbered on from where they were.

## 4. Fill the row
1. Tap **Fill Piero's row**.
   - [ ] You're back on the notepad and Piero's row has every piece filled, matching the monitor.
2. Tap one of Piero's boxes.
   - [ ] The bar reads "On the page: 1:4x.x. Type to change it." Type a different split and tap **Next**:
         it changes, so a misread can always be corrected.
3. Scan another rower but stop part way: after one screen tap **Fill (name)'s row with k pieces**.
   - [ ] Only those k boxes fill; the rest stay as they were.

## 5. A one-piece workout
Open the notepad of a workout with a single piece (e.g. a 2k or 5k), tap a camera, photograph that
piece's results.
- [ ] One row: the total time, metres, split and rate from the top line of the monitor's table, and
      "1 of 1 read" in green. **Fill** puts that split in the rower's one box.

## 6. Not a monitor
Tap a camera and photograph something else (a wall, the erg's seat).
- [ ] A red line: "Couldn't find the results table on that photo…", still on the camera, nothing filled.

## 7. Nothing counts (Piero)
After scanning Piero's monitor in:
- [ ] Piero's **Profile** volume, sessions and PBs, and **Rankings**, haven't changed.

## 8. Swipe back
- [ ] The scan screen swipes back to the notepad from the left edge; the notepad then shows any rows
      already filled.

## 9. Light mode
- [ ] Settings → Appearance → Light: the scan screen, its banner and table read clearly.

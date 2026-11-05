# Coach notepad, phase NP3 (many pieces, tests, timed pieces) — test checklist

Decision 96 in `docs/design/v2-decisions.md`; plan in `docs/design/coach-notepad-build-plan.md`; boards
`docs/design/v4/CoachNotepadPieces.dc.html` and `CoachNotepadTest.dc.html`. Branch `t42-coach-notepad`.

Accounts: **Coach_J** (coach) and **Piero** (rows). You need three workouts set for **today** for a squad
Piero is in (New workout, **with pieces added**, or just a title like "20 x 250m"):
- **A** — many pieces: **20 × 250m** (or 8 × 500m: anything over 4 reps).
- **B** — a test: set it as **2k** in New workout's test choice.
- **C** — timed pieces: **4 × 10:00** (or title "4 x 10'").

## 0. Run the migration on the Dev project (do this first)
The app works before you do (typing and scanning interval pieces are fine), but a scanned or posted 2k
only keeps its 500m splits once this is run, and before it a workout set by title alone ("4 x 500m")
refuses scores in columns 2 onwards.
1. Open **supabase.com** → sign in → click the **Dev** project (the one the RP Dev and TestFlight builds use).
2. In the left sidebar click **SQL Editor** → **+ New query** (top left of the editor).
3. In Finder open `docs/migrations/2026-11-05-coach-notepad-np3.sql` (in the project folder), press
   **Cmd+A** then **Cmd+C**. Click into the empty query box in Supabase and press **Cmd+V**.
4. Click **Run** (bottom right, or **Cmd+Return**).
   - Expect **Success. No rows returned**. Any red error: screenshot it and send it to Claude.
5. Click **Run** a second time: it should succeed again (it's safe to run twice).
6. **Before the App Store build** (Release, the production project): run the same file there too. Posting
   writes the new column, so a production build without it would fail to post a 2k with splits.

## 1. Install the build
In Xcode choose **RP Dev** and **your iPhone**, press **Cmd+R**. Sign in as **Coach_J**.

## 2. Many pieces (workout A)
**Workouts** → A → **Open notepad**.
- [ ] Above the Scores card: a **Summary | Every piece** switch, on Summary.
- [ ] Summary has columns **Rower · Done · Avg · Best · Fade**, a camera by each name, and the line
      "Splits /500m. Fade is the last five pieces against the first five. Tap a name for every piece."
1. Tap a name.
   - [ ] It opens to every piece as tiles, five to a row, numbered 1–20; tap the name again to close.
2. Tap tile **1** and type a split, then **Next** several times.
   - [ ] The entry bar opens as on the normal page; Next walks down the ergs and the tiles fill in.
   - [ ] **Done** counts up ("3/20"), **Avg** and **Best** follow what you typed.
3. Fill pieces 1–5 at about **1:40.0** and 16–20 at about **1:42.0** for one rower.
   - [ ] **Fade** reads **+2.0** in **red**. Make the last five 1:41.0 instead: **+1.0**, grey.
4. Tap **Every piece**.
   - [ ] Names stay put on the left (full names, not cut short to a letter or two) and the boxes swipe
         sideways through pieces 1–20; the line under it says "Swipe sideways for pieces 1–20. Names stay put."
   - [ ] Tapping a box types into it, as on the normal page.

## 3. A 2k test (workout B)
First, as **Piero**: row a 2k (or photograph a 2k results screen that shows the four 500m rows under the
total), post it with **Link this session** to workout B.
- [ ] Posting works as normal.
Then as **Coach_J**: **Workouts** → B → **Open notepad**.
- [ ] The title has a **Test** chip; the line under it ends "· N rowers".
- [ ] The Scores card has **Rower · Time · Split · Rate**; Piero's row shows his time with the blue dot.
- [ ] The footer reads "from their own post. The club's 2k board only takes rowers' own posts; numbers
      you scan or type stay on this page."
1. Tap **Piero**.
   - [ ] It opens to four tiles **500m · 1,000m · 1,500m · 2,000m** with his 500m splits, and
         "500m splits from their own post."
2. Tap another rower's **time** box and type a 2k time (**6 5 2 . 4**), **Next**.
   - [ ] The bar opens on **Time**; the row shows 6:52.4 with its split. Tap the name: "You typed the time.
         Scan the monitor to add 500m splits."
3. Tap a rower's **camera** and photograph a 2k results screen.
   - [ ] The scan screen says "With its 4 splits: … That's the piece." **Fill** → back on the page, the
         row opens to the four splits and "500m splits read from the monitor. The photo wasn't kept."
4. A rower who posted their 2k **before today's build**:
   - [ ] Their row opens to "Their post doesn't have 500m splits: it was posted before they were kept, or typed in."

## 4. Timed pieces (workout C)
**Workouts** → C → **Open notepad**.
- [ ] The card's top right reads "metres · split /500m".
1. Tap a box.
   - [ ] The bar offers **Split | Metres**; type **2 6 5 0** in Metres, **Next**.
   - [ ] The box shows **2,650** with the split under it (**1:53.2** for 10:00).

## 5. Nothing counts (Piero)
- [ ] After scanning and typing for Piero: his **Profile**, PBs and **Rankings → 2k** are unchanged. His
      own posted 2k is on the board as before (the notepad never adds to it).

## 6. Light mode
- [ ] Settings → Appearance → Light: Summary, Every piece, the tiles and the test card read clearly.

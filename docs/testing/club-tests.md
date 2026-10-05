# Club tests — setup and test checklist

Decision 28 in `docs/design/v2-decisions.md`. Run against the **staging** Supabase project
(Rowing-Pals-Dev). Tick each box; anything that doesn't match "Expect" is a bug — note the step.

## Cast

- **A** — you, on your phone: the owner of UEA Boat Club.
- **B** — a plain member of UEA Boat Club (not an admin), e.g. your test account on the simulator.

## Part 1 — One-time setup

### 1. Run the club-tests migration
1. Open **supabase.com**, sign in, and open the **Rowing-Pals-Dev** project.
2. In the left sidebar click **SQL Editor**, then **+ New query** (top left of the editor).
3. In Finder, open `docs/migrations/2026-10-04-club-tests.sql` (in the project folder) with
   TextEdit, press **Cmd + A**, then **Cmd + C**.
4. Click in the empty query box in Supabase, press **Cmd + V**, then click **Run** (bottom right).
5. Expect: **Success. No rows returned.**

## Part 2 — In the app (build from branch `t31-tab-reselect`)

### 2. Who can add a test
- [ ] **A**: **Rankings** → **Test results**. Expect the nine standard tiles, then a blue
      **＋ Add test** tile.
- [ ] **B**: the same screen. Expect **no** Add test tile (members can't add tests).

### 3. Adding one (A)
- [ ] Tap **＋ Add test**. Expect a sheet "Add a club test" with **Distance / Time** and a
      number box ending in "metres".
- [ ] Type **2000**. Expect red **"That's already a standard test."** and the button greyed out.
- [ ] Clear it and type **750**. Expect "Shown as 750m. Results rank by fastest time." and the
      button **Add 750m test**. Tap it. Expect the sheet to close and a **750m** tile with "—"
      after the standard tiles (before Add test).
- [ ] **＋ Add test** again → type **750** → expect red **"Your club already has a 750m test."**
- [ ] Tap **Time**, type **20** → **Add 20min test**. Expect a **20min** tile after 750m.

### 4. Members see it (B)
- [ ] **B**: on Test results, tap **Rankings** in the tab bar (refreshes). Expect the **750m**
      and **20min** tiles, still no Add test tile.
- [ ] Tap **750m**. Expect its leaderboard: "Nobody's set this test yet", and **no** bin button
      (only admins and up can delete).

### 5. Posting a result (A or B, on a phone — a test needs the camera photos)
1. Tap the **＋** (Log) button, take the photos with the rear camera on an erg monitor.
2. On **Review**, set the **Main** piece's distance to **750** (and any time), and confirm the
   stroke rate.
3. Tap **Session type**. Expect the list to end with **750m test** and **20min test**. Pick
   **750m test**.
- [ ] Change the distance to **760**. Expect **"A 750m test must be exactly 750m."** and Post
      unavailable. Set it back to **750**.
- [ ] Tap **Post**. Then Rankings → Test results: the **750m** tile shows your time; tap it —
      you're on its board.
- [ ] Open the post (Feed → the post). Expect the test banner to name **750m**.

### 6. Deleting (A)
- [ ] Rankings → Test results → **20min** → tap the red **bin** (top right) → **Delete**.
      Expect the board to close and the 20min tile to be gone.
- [ ] **B** refreshes (tap Rankings): the 20min tile is gone for them too.

## Cleanup
Delete the 750m test the same way if you don't want to keep it (its results go with it; the
posts stay on the feed).

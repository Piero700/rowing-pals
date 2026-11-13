# Automatic leaderboards: phone test checklist

Decision 104 in `docs/design/v2-decisions.md`, on branch `t45-combined-test`. Use your own account (**Piero**).

## 1. Run the database change (staging), before installing the build

**Done 13 Nov 2026 (by Claude):** run on staging; it ranked 10 past posts (15 results, 8 new PBs), and a second run added nothing. Your 30 minutes from 3 Nov is on the 30min board as a PB (7,929 m). Skip to section 2. The steps below are for production later.

1. Go to **supabase.com**, sign in, and open the **staging** project (the one the TestFlight and Xcode builds use).
2. Click **SQL Editor** in the left bar, then **+ New query**.
3. In Finder, open `Rowing Pals/docs/migrations/2026-11-13-automatic-leaderboards.sql`, select everything (**⌘A**), copy (**⌘C**), and paste it into the query box (**⌘V**).
4. Click **Run** (bottom right).
   - [ ] It finishes with a small table: **sessions_ranked**, **results_added** and **new_pbs**. (A dry run on 13 Nov showed 10, 15 and 8.)
5. Running it again is safe: the second run adds nothing.

## 2. Install the build
From Xcode (section 0 of `docs/testing/combined-t45.md`), or the next TestFlight build once it's uploaded.

## 3. Your past posts
1. **Rankings** → **Test results** → **30min**.
   - [ ] Your 30 minutes at rate 20 from last week is on the board, with its metres.
2. **Profile** → **PBs** → **30min**.
   - [ ] It shows as your 30min PB, dated the day you rowed it.
3. Open that post from **Profile → Posts**.
   - [ ] It has the PB glow.

## 4. A new continuous piece (needs the erg)
1. Row any piece at a test distance or time (for example 2,000 m or 4:00), at any rate. Leave **Session type** on **Training**.
2. Photograph the monitor's **View Detail** screen and post it with **Include on leaderboards** on.
   - [ ] It appears on that test's board in Rankings.
   - [ ] If it's your best or your first at that distance, the post glows as a PB and you get the PB alert.
3. Post another piece at the same distance, slower.
   - [ ] The board still shows your faster one; no PB glow on the slower post.

## 5. Intervals, and the next screen (needs the erg)
1. Row an interval workout with more reps than fit on one screen, for example **10 × 500m** (Workouts menu on the PM5).
2. Open **Memory → View Detail** for it, photograph the first screen and go to Review.
   - [ ] Under the piece: **"5 of 10 reps read"** (or however many show), with a hint to photograph the next screen.
3. Scroll the monitor down to the next reps. On Review, add a photo of that screen (the same way you add any photo).
   - [ ] No new piece appears; the line now reads **"10 of 10 reps read"**.
4. Post it.
   - [ ] Your best 500 is on the **500m** board (Rankings → Test results → 500m).
   - [ ] Nothing new on the **5k** board: the workout's total doesn't count.

## 6. What never ranks
- [ ] A piece labelled **Warmup** or **Cooldown** at 2,000 m: not on the 2k board.
- [ ] Any piece with **Include on leaderboards** off: not on any board.
- [ ] A session typed in (**Enter session manually**) or started from a library photo: not on any board.

## 7. Session type is now a label
1. Post a 2,000 m piece and, when Review says **"This looks like a 2k test"**, tap **No**.
   - [ ] It's still on the 2k board (the prompt now says "It goes on the 2k leaderboard either way").
2. Post one and tap **Yes**.
   - [ ] The post is called "2k test" and the zone is AN.

## Built beyond the brief
- On Review, an interval piece shows how many reps were read ("7 of 20 reps read"), with a hint to photograph the next screen.
- The photo of a next screen isn't kept with the post; only its reps are (as with the coach's scan).
- **Include on leaderboards** off now keeps a session's results off the test boards too (before, it only covered volume).
- The back-fill can't rank reps from interval posts made before this build (their rep times weren't kept). An old timed-rep workout (e.g. 3 × 10:00) from before 5 Nov may show on a timed board as its total: delete that post's result if you see one.

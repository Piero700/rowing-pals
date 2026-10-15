# Predictions, Your bests, swipe-to-delete — test checklist (decisions 60, 64, 65; 2026-10-15)

## 0. Run the migration on staging first
1. Supabase dashboard → the **staging** project → **SQL Editor** → **+ New query**.
2. Open `docs/migrations/2026-10-15-declared-bests.sql`, select all (Cmd+A), copy (Cmd+C), paste (Cmd+V).
3. Click **Run**. Expect **Success. No rows returned**. Any red error: stop and send it to Claude.

## 1. Install the build
Plug in your iPhone; in Xcode choose the **RP Dev** scheme and your iPhone; press **Cmd+R**.

## 2. The prediction cards (Profile)
- [ ] Open Profile: the 2k and 5k cards say **Calculating…** with a spinner, then show the numbers.
- [ ] Pull down to refresh several times: the numbers stay (no "Couldn't work out a prediction").
- [ ] Tap **ⓘ** on a card: "2k prediction" opens with "How we got this". With no number yet it
      explains how predictions work instead of doing nothing.
- [ ] Turn on Airplane mode, pull to refresh: the old numbers stay. (On a fresh launch offline:
      "Couldn't reach the server…" and **Try again**.)

## 3. Every all-out piece counts (engine v1.6)
- [ ] Your recent 20-minute test now moves **both** the 2k and the 5k: compare with before.
- [ ] Neither prediction is slower than a split you've held over a longer piece in the last 30
      days. If that rule set it, ⓘ shows "You've already held x:xx.x /500m for N m…".

## 4. Your bests
- [ ] **Settings → Your bests** (under Edit profile): 2k and 5k rows, and **Add another best**.
- [ ] 2k: type **6 4 0 0** (6:40.0): "1:40.0 /500m" appears under it.
- [ ] Add another best → **A time** → 2 0 0 0 (20:00), metres **5400**: titled "20 min", "1:51.1 /500m".
- [ ] Add another best → **A distance** → 1000 and nothing else: "Add the time too." and **Save** is greyed.
- [ ] Remove it with the ✕. **Save**: back to Settings. Reopen: your bests are there.
- [ ] Profile: the predictions now use them (ⓘ shows "Based on a best you entered…" if nothing
      you've logged outweighs them).
- [ ] New account: after **About you** there's a **Your bests** step with **Skip for now**.
- [ ] A coach-only account has no Your bests row and no bests step.

## 5. Swipe to delete a workout (Coach → Workouts)
- [ ] Swipe a card left, however far: it stops with the red **Delete** showing. Nothing is deleted.
- [ ] Tap the card: it closes. Swipe again, tap **Delete**: the workout goes.

## Added beyond what you asked — check these
- [ ] **Try again** on the card, and keeping the last numbers when a reload fails.
- [ ] The **split shown under each best** as you type it.
- [ ] Bests **count for 30 days** from when you enter them, then your own pieces take over; a best you
      haven't changed keeps its date when you save again.
- [ ] Your club's **coaches' predictions** for you use your bests too.
- [ ] The **"You've already held…"** line in the prediction's explanation.

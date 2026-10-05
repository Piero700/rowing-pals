# Pace Engine predictions — test checklist

Decisions 30–31 in `docs/design/v2-decisions.md`. Run against the **staging** project after
`docs/migrations/2026-10-05-pace-engine-inputs.sql` has been run (SQL Editor → + New query →
paste → Run).

The engine itself is proven separately: in Terminal, `cd Packages/PaceEngine` then
`swift test` — expect all 38 golden cases and 34 parsing checks to pass.

## 1. What a post records (your phone)
- [ ] Log a session (camera photos). On **Review**, expect a **Zone** dropdown (UT2 · Steady
      state … AN · All-out) where "Main workout label" used to be, and **How hard did it feel?
      (optional)** under it.
- [ ] Set **Session type** to a test (e.g. 2k test). Expect Zone to switch to **AN · All-out**
      with a line explaining why; you can still change it.
- [ ] Post. In the feed, the main split's badge reads the zone (e.g. **UT2**) — or the test's
      name for a test.

## 2. Predictions (your phone)
With no zoned erg sessions in the last 30 days:
- [ ] **Profile** → the **2K · Predicted today** and **5K · Predicted today** cards show "—" and
      advice on what to log.

Then log a few sessions over a few days (one hard effort — a 2k test or a TR piece — makes the
biggest difference):
- [ ] The cards show a predicted time, its split and **High / Medium / Low confidence**, plus a
      line of advice when there is one.
- [ ] Tap **ⓘ** on a card. Expect **"2k prediction"** with the arithmetic top to bottom (your
      anchor session, distance and zone corrections, **Your 2k pace**, projection, training
      volume, **Predicted split**, **Predicted time**), then **Confidence** and **How to improve
      it**. No weight-adjusted or age-graded numbers anywhere.
- [ ] **Rankings → Test results**: each distance tile (500m, 1k, 2k, 5k, 6k, 10k, and distance
      club tests like 750m) shows **Predicted m:ss.s** under your best. Timed tiles (4min,
      30min, 60min, 30s…) show none — the engine predicts distances.

## 3. Private details (your phone)
- [ ] **Settings → Edit profile**: **Date of birth** (Add date of birth → picker, Remove) and
      **Weight** (kg), with the "Private…" note. Type **12** in Weight → red "Enter a weight
      between 25 and 250 kg." Enter a real weight and a date → **Save changes** → leave and
      come back: both kept.
- [ ] Open your profile from another account: no age or weight shown anywhere.
- [ ] Supabase → **Table Editor → athlete_private**: one row for you. (Only you can read it
      from the app.)

## 4. Interval rep distance (needs a real interval workout)
- [ ] Row an interval workout with fixed-distance reps (e.g. 4x500m/1:00r), photograph the
      PM5's summary, post it as **AN** or **TR**. Supabase → Table Editor → **segments** → the
      new main segment's **rep_distance_m** is **500**. (Read from the monitor's title; not yet
      checked against a real photo — send one to Claude if it comes out empty.)

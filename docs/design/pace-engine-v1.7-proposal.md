# Pace Engine v1.7 — every erg post counts (proposal, 2026-11-09)

**Status:** built (2026-11-13) as decision 104, with **personal Paul's Law** added at the user's
request ("Add personal Paul's Law"; SPEC §5.21: the rower's own seconds per doubling from their
continuous all-out pieces in the last 90 days, shrunk towards 5, within 2.5–8). Choices A–C were
built as recommended; the user can change any. The built model is `PaceEngine/SPEC.md` §5.17–5.21,
which wins where this proposal differs (e.g. the steady-change minimum is 2 pieces each side in
all, and the steady-zone blend takes a weighted median).

**Asked for (user, 2026-11-09):** "performance tends to improve if you do loads of UT2 volume. The
predictions should take into account all the erg posts, not only the hardest ones."

**What this overrides.** SPEC §7.2 and §7.9 say the constants are seeds to be tuned against real
rowers' results after launch, and the engine handoff says not to re-tune formulas. This request
changes the model before that data exists. Every new number below is a **seed** in the same sense,
and is listed in `EngineConfig` so it can be tuned later.

---

## 1. What the engine does today (v1.6)

| Part | Today |
|---|---|
| The number | Only the **best zone you've logged** sets it: any all-out (AN) piece, else race pace (TR), else threshold (AT), else UT1, else UT2. Once you have one all-out piece in 30 days, **every steady row is ignored for the number**. |
| Steady rows | Used only to check that your zones agree with each other (confidence) and for volume. |
| Volume | 30-day minutes × zone weight. **0 s for anything from 600 to 1,800** (about 10 to 30 hours of UT2 a month), −1.5 s at 3,600. So for most club rowers, more UT2 changes nothing. |
| Which pieces | Main pieces of sessions that have a zone. Extra pieces, warm-ups, cool-downs and old posts with no zone are never read, not even as volume. |
| Floor | Never slower than a split you've already held over a longer piece, in any zone (decision 65). |

## 2. The physiology the change rests on

1. **A 2k is mostly aerobic.** Laboratory studies of 2,000 m ergometer racing put the aerobic share
   at roughly 70–85 %, and a 5k higher still (about 85–90 %). So most of a 2k is set by the same
   aerobic engine that UT2, UT1 and threshold work trains and that steady pace reveals.
2. **Steady pace at a fixed effort tracks aerobic fitness.** For one rower, a UT2 split that drops
   at the same rate and the same felt effort is the standard sign that the aerobic base has
   improved. This is why coaches watch "split at rate 20".
3. **The generic zone gaps don't fit everyone, but they cancel within one rower.** "UT2 is 2k pace
   + 22" is an average; one rower's real gap might be +18, another's +26. That is why steady rows
   are poor evidence of the 2k *level* when a test exists. But the rower's own gap doesn't change
   much week to week, so the **change** in their steady pace since their test is good evidence of
   the change in their 2k.
4. **Training volume improves fitness with diminishing returns** (the impulse-response model the
   engine is named after). Each doubling of volume buys about the same gain, not each extra hour.
5. **A test is a measurement.** Volume rowed *before* a test is already inside its time. Only
   training *after* it can have moved the rower on.

## 3. The proposed model

### 3.1 Every piece is read (inputs)
- Every erg session's **main** pieces, as now, tagged with the session's zone. A ranked piece
  (`test_results`) is marked as one continuous piece but keeps **the session's zone and RPE**, so a
  ranked 30-minute UT2 row at rate 20 is read as UT2, never as all-out. (This is how the app
  already tags pieces; the leaderboard change in the other session doesn't alter it.)
- **New: volume-only pieces.** Warm-ups, cool-downs, extra pieces (see choice C) and old posts with
  no zone count towards training volume as UT2 minutes, but never towards pace. New input field
  `volume_only: true`.

### 3.2 No all-out piece: every steady zone together (replaces "the best zone only")
Each AT, UT1 and UT2 piece is turned into its own 2k equivalent (§2 inversion, its own RPE
correction, and the rate correction of choice B), and they are averaged, weighted by
`minutes × recency (halving every 14 days) × zone trust`, where zone trust is `1 / range_base²`
(AT 0.44, UT1 0.25, UT2 0.20). Threshold work counts most per minute because its gap to all-out is
smallest; a big month of UT2 still counts because it is many minutes. A consistent rower gets the
same 2k as today (the zones agree by construction); a rower whose zones disagree gets the
trust-weighted middle instead of whichever single zone ranked highest.

### 3.3 With an all-out piece: "your steady rows since your test" (new term)
The all-out blend of v1.6 still sets the level (AN, else TR). Every other piece — TR (when AN
anchors), AT, UT1, UT2 — becomes a **supporting piece** with its own 2k equivalent, as in 3.2.

```
for each zone with supporting pieces both on/before the anchor day and after it:
    before_z = duration-weighted median 2k equivalent, pieces on or before the anchor day
    after_z  = duration-weighted median 2k equivalent, pieces after it
    change_z = after_z − before_z
steady_change = duration-weighted mean of change_z         (needs ≥ 2 pieces each side in all)
transfer      = clamp(0.5 + 0.1 × log2(target / 2000), 0.3, 0.7)     # 2k 0.50, 5k 0.63
steady_gain   = clamp(transfer × steady_change, −3.0, 0.0)
```

Comparing **within a zone** is what makes the rower's personal gap cancel. `transfer` is below 1
because a steady split only shows the aerobic part of a test, and rises with the target because a
5k is more aerobic than a 2k. **`steady_gain` can only make the prediction faster** — an easy piece
never drags it slower than what the rower has held all-out (decision 65). If steady rows have got
slower, the number stays and the flag `steady_pace_slower` adds the advice "Your steady rows are
slower than around your last test — if you're tired, a test now may come in slow."

### 3.4 Training volume (changed)
Still the 30-day minutes × zone weight (now including volume-only minutes). The flat 600–1,800
plateau is replaced by a curve with diminishing returns:

| 30-day load | Modifier |
|---|---|
| 0 | +3.0 s (as today) |
| 600 | 0.0 (as today) |
| above 600 | **−0.75 s per doubling** (1,200 → −0.75, 2,400 → −1.5, 4,800 → −2.25) |
| cap | −2.5 s |

The slower side (below 600, detraining) applies as today. The **faster side** is the training
after the measurement, so with an all-out anchor it is multiplied by the share of the 30-day load
rowed **after** the anchor day (a test yesterday → about 0; a test three weeks ago → about two
thirds). When 3.3 has measured a steady change, that measured change **replaces** the faster side
of volume, because volume would otherwise count the same improvement twice. With steady rows only,
the faster side applies in full.

### 3.5 The range (decision 48 kept)
Same terms, added in quadrature, plus:

| Term | Value |
|---|---|
| Base, steady-only blend | trust-weighted between the zones present: `sqrt(Σ minutes / Σ(minutes / base²))` |
| Stale anchor | **halved** when 3.3 measured a steady change: the rows since the test track what happened after it |
| Steady gain | half of `|steady_gain|` |
| Volume gain | half of the faster side of the volume modifier |

So steady rows since a stale test narrow the range (less doubt about drift) while the nudge itself
carries some doubt. Confidence scores are unchanged.

### 3.6 Floor and clamps
Unchanged and applied last: never slower than a split held over a longer piece; never past the
physiological limits.

## 4. Worked example (2k, rower whose true 2k split is 1:45.0)
- All-out 2k 20 days ago: 7:00.0. UT2 16k rows before it: 2:07.0. UT2 rows since, same rate and
  felt effort: 2:05.0.
- v1.6: 7:00.0 (steady rows ignored; volume 0 on the plateau).
- v1.7: steady change −2.0 s → gain 0.5 × −2.0 = **−1.0 s/500m** → **6:56.0**; 5k −1.26 s/500m.
  Range: base 0.75, stale term halved (6 days × 0.05 / 2 = 0.15), gain 0.5 → ±0.92 s/500m, ±3.7 s.
- Same rower, no UT2 rows before the test (no steady change to measure), 2,400 load with two thirds
  after the test: volume −1.5 × 0.67 = **−1.0 s/500m**.

## 5. The user's choices
- **A. Volume curve:** −0.75 s per doubling above 600, capped at −2.5 (recommended), or keep today's flat plateau and let only steady rows count.
- **B. Rate:** correct each steady piece by 1.5 s/500m per stroke away from its zone's usual rate (capped at ±4.5 s), so a UT2 at rate 22 and one at rate 18 compare fairly (recommended), or ignore rate.
- **C. Extra pieces:** volume only (recommended: the session's zone describes the main piece, and an easy extra row in an AN session would read as a slow all-out piece), or pace too, with the session's zone.
- **D. Go-ahead:** build v1.7 as above (Python first, Swift port, app inputs, decision 104, phone checklist).

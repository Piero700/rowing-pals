# Predictions from every erg post — phone checklist (decision 105, Pace Engine v1.7; 2026-11-13)

Branch `t46-predictions-every-post`. No SQL migration and no Supabase change: everything happens
on the phone, from sessions you already have.

What changed, in one line each:
- Steady rows (UT2, UT1, AT) **since your last all-out piece** can make your 2k and 5k faster, never slower.
- With no all-out piece, **all** your steady zones count together, not just the best one.
- Every minute counts as training volume, warm-ups and cool-downs included, and more volume keeps helping a little.
- With all-out pieces at two or more distances, the 5k uses **your own** Paul's Law.

## 1. Install the build
1. On the Mac, open Terminal and run `cd "/Users/piero/Documents/Rowing app/Rowing Pals/.claude/worktrees/t46-predictions"` then `open "Rowing Pals.xcodeproj"`.
2. In Xcode's top bar choose the **Rowing Pals** scheme (RP Dev) and your iPhone.
3. Press **Cmd+R**. Wait for the app to open on the phone, signed in to your staging account.

## 2. Nothing broke
- [ ] Open **Profile**. The 2k and 5k cards say **Calculating…**, then show numbers.
- [ ] Tap **ⓘ** on the 2k card. "2k prediction" opens with **How we got this**, a **Confidence**
      card and a ± after the time. Tap **Done**.
- [ ] Pull down to refresh three times: the numbers stay.

## 3. Steady rows since your last all-out piece
Do this with an account that has **one all-out (AN) piece at least a week old** and UT2 rows both
before and after it. (A test account is fine; post sessions with **Type it in** if needed.)
1. Note the 2k prediction on Profile.
2. Post two UT2 sessions dated **after** the all-out piece, each about 60 minutes, at a split
   **2 seconds faster** than your usual UT2 and the same rate (e.g. rate 18).
3. Back on Profile, pull down to refresh.
- [ ] The 2k prediction is faster (about 1 s/500m, so about 4 s on the 2k time).
- [ ] Tap **ⓘ**: How we got this shows **"Your steady rows since your last all-out piece"** with a
      minus value (e.g. −1.0 s).
- [ ] The 5k card moved a little more per 500m than the 2k.
4. Now post two UT2 rows after it **4 seconds slower** than usual, and delete the two fast ones.
- [ ] The prediction is never slower than your all-out piece shows.
- [ ] Under **How to improve it**: "Your steady rows are slower than around your last all-out
      piece. If you're tired, a test now may come in slower than this prediction."

## 4. No all-out piece: every steady zone together
Use an account with only steady rows in the last 30 days (no AN or TR).
- [ ] Tap **ⓘ** on the 2k card: the first line reads **"Your steady rows (N pieces), middle one:
      UT2 16,000m"** (or AT/UT1), and N counts every steady row, not just one zone.
- [ ] Post one AT (threshold) session: the prediction can move, even though UT2 rows remain.

## 5. Stroke rate
- [ ] On an account with only steady rows, post a UT2 row at **rate 22** (4 above UT2's usual 18).
      If ⓘ's first line names that row, **"Stroke rate, read at the zone's usual rate"** shows
      **+4.5 s** (capped), so the higher rate doesn't flatter the 2k.

## 6. Training volume
- [ ] Post a session with a **warm-up** and **cool-down** photo as well as the main piece. In ⓘ
      the "Training volume, last 30 days" line can change, but the first line (the piece the
      prediction rests on) is never the warm-up or cool-down.
- [ ] The day after a fresh all-out 2k test, the 2k prediction equals that test: volume rowed
      before the test doesn't beat it.

## 7. Your own Paul's Law
Use an account with **continuous all-out pieces at two distances** in the last 90 days, e.g. a
2k test and a 5k or 6k test (Your bests count too: Settings → **Your bests**).
- [ ] Tap **ⓘ** on the **5k** card: the line reads **"Paul's Law out to 5k (yours: X.X s per
      doubling)"**. If you fade more than average, X.X is above 5.0; if less, below.
- [ ] With only one distance (e.g. just 2k tests), the line is plain **"Paul's Law out to 5k"**.

## 8. Coaches
- [ ] Sign in as a coach → **Coaching**: each rower's prediction and ± still show. Open a rower
      whose steady rows got faster since their test: their 2k has moved like yours did.
- [ ] A rower's "No session in 60+ days" flag still appears only after 60 days with nothing.

## Added beyond what you asked — check these
- [ ] **Stroke-rate correction** for steady pieces (1.5 s per stroke, capped at 4.5): the
      recommended option, built without a separate answer.
- [ ] **Extra pieces count as volume only**, not pace (recommended option, not separately answered).
- [ ] **Volume curve**: more volume keeps helping (0.75 s/500m per doubling, capped at 2.5 s).
- [ ] With **no all-out piece**, every steady zone blends together (part of "all the erg posts").
- [ ] Sessions are read **90 days** back for predictions, for you and in Coaching (for your own Paul's Law).
- [ ] The **advice** when steady rows got slower (section 3, step 4).
- [ ] The numbers in How we got this's **labels** now use fixed-width digits (e.g. "6.1 s per doubling").

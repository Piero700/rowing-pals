# First-run tour — phone checklist (decision 109, 2026-11-19)

Branch `t47-tour`. Nothing to run on staging: the tour stores nothing in the database.

The tour starts by itself only while helper text is on (your first 7 days, or Settings → Help → Helper
text switched on). Your own account has used the app for longer, so to see it:

1. Open the app (rower version) → **Profile** → the settings button at the top right.
2. Scroll to **Help** → tap **Show the tour again**. Settings closes.

Fixed 2026-11-20: **Show the tour again** used to close Settings and leave you on Profile with no
tour, for anyone whose tour had never started by itself (it cleared a "seen" flag that was already
clear, so nothing changed). It now bumps a counter of its own, so every tap starts it.

- [ ] Tap **Show the tour again** twice in a row (finishing the tour in between): it starts both times.

## Rower version
- [ ] The screen dims, with a clear rounded hole round **Feed**, and a card above the bar: "1 of 5 · Your club's sessions".
- [ ] **Next** moves the hole to the **+** (Log) — "Log a session" — then Rankings, Calendar, Profile; the tab behind changes each time.
- [ ] Card 5 says **Done**, with no Skip. Done closes it and you're back on **Feed**.
- [ ] Tapping the dimmed screen, or the control inside the hole, does nothing while the tour shows.
- [ ] **Skip** on any card closes it and goes back to Feed.
- [ ] Close and reopen the app: the tour doesn't come back.
- [ ] Light mode (Settings → Appearance → Light mode), then Show the tour again: the card reads clearly.
- [ ] With the bar hidden (scroll down the Feed first), Show the tour again: the bar comes back for the tour.

## Coach version (an account that coaches)
- [ ] Switch to the coach version. The first time, the coach tour starts by itself if helper text is on; otherwise tap your picture at the top right → **Settings** → Help → **Show the tour again**, then close Settings and your profile.
- [ ] Cards: Rowers, Workouts, Boats, Calendar, then the **+** ("Make something new"). Done goes back to Rowers.

## A brand-new account
- [ ] Sign up a new account and finish onboarding: the rower tour starts by itself about a second after the Feed appears.

## Added beyond the request (please check you want them)
- **Show the tour again** row in Settings → Help.
- The tour starting by itself only while helper text is on (so existing users aren't shown it).

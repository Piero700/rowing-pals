# Coach version, phase CV1 (the coach's own app) — test checklist

Decision 67 in `docs/design/v2-decisions.md`; plan in `docs/design/coach-version-build-plan.md`.
Branch `t41-coach-version` (built on `t40-coaching-phase2`, which isn't merged yet).
**Don't merge until every box you can tick is ticked on your phone.**

You need two accounts in the same club:
- **Coach_J** — "Coach only" and made a coach (already set up on staging).
- **Piero** — rows, and owns the club, so he can make himself a coach (step 4).

## 0. Run the migration on staging (do this first)
1. Supabase dashboard → the **staging** project → **SQL Editor** → **+ New query**.
2. Open `docs/migrations/2026-10-16-coach-version.sql`, select all (Cmd+A), copy (Cmd+C), paste (Cmd+V).
3. Click **Run**. Expect **Success. No rows returned**. Any red error: stop and send it to Claude.

## 1. Install the build
1. Plug in your iPhone; in Xcode choose the **RP Dev** scheme and **your iPhone**.
2. Press **Cmd+R**.

## 2. A coach who doesn't row (sign in as Coach_J)
- [ ] The app opens straight into the **coach version**: big title **Rowers**, a round **Squads**
      button and your picture top right, and at the bottom a glass bar with **Rowers · Workouts**
      and a solid blue **+** beside it. No Feed, Rankings or Profile tabs.
- [ ] **Rowers** is the old Coaching list: the "All squads · Behind target" button (opens Squad and
      sort), the stat cards, "This week · N rowers" and a card per rower. Tap a card: that rower's
      page opens; swipe from the left edge or tap back to close it.
- [ ] Scroll the list down: the bar shrinks away; scroll up: it comes back.
- [ ] Tap **Rowers** again while on it: the list scrolls to the top and refreshes.
- [ ] Tap **Squads** (top right): Squads opens. Change a squad, close it: the Rowers list shows the
      change.
1. Tap **Workouts**.
- [ ] Big title **Workouts**, your picture top right, and Today / Upcoming / Past — **no New
      workout button** on the page (it's the +). With none set: "No workouts yet. Tap + to set one…".
2. Tap **+**.
- [ ] **New workout** opens. Set one for today (any title, Whole club) → **Set workout**.
- [ ] Back on Workouts, it's under **Today** straight away.
- [ ] Swipe it right to left: **Delete** shows and stops; tap it: it fades away.
3. Tap your **picture** (top right).
- [ ] **Profile** opens: your picture, name, "Coach · UEA Boat Club". **No** "Switch to rowing"
      card (you don't row). **CLUB**: your club ("Your crew", or "Members, requests and roles" if
      you manage it) and **Squads**. **ACCOUNT**: Settings, Edit profile, Log out (blue).
- [ ] **UEA Boat Club** opens Your crew (or Manage club). **There's no Coaching button on it any more.**
- [ ] **Settings** opens as a sheet. No switch row at the top (you don't row).
- [ ] **Edit profile** opens Edit profile. The account type line reads "Coaches who don't row get
      the coach version: no rankings and no Log button." Go back without saving.
- [ ] Back, then back again: you're on the tabs.

## 3. The side (sign in as Piero, or any account that rows)
1. **Profile → Settings → Edit profile**.
- [ ] Under **RANKINGS**, after Level: **Side** — "The side you row on in sweep boats. Your coach
      sees it when seating you." — **Stroke side · Bow side · Both**, none chosen yet.
2. Choose **Bow side** → **Save**. Reopen Edit profile.
- [ ] **Bow side** is still chosen.
3. (Optional, a new test account) Sign up: on **About you**, after Level, there's **Side** with the
      same three choices and a line explaining it. You can leave it and carry on.

## 4. Someone who rows and coaches (Piero)
1. As Piero: **Profile → Club → Manage club → you → Make coach** (owners can make themselves a coach).
- [ ] The app stays on the **rower version** (Feed · Rankings · Profile, Log button).
- [ ] **Profile → Club**: **no Coaching button** any more.
2. **Profile → Settings**.
- [ ] At the very top: a card with a round blue icon, **Switch to coaching**, "You row and coach.
      The app opens in the one you used last."
3. Tap it.
- [ ] Settings closes and the app becomes the **coach version** (Rowers · Workouts · +).
4. Tap your **picture** top right.
- [ ] Profile shows a card **You coach and row** with **Switch to rowing** and "In the rower
      version, Settings has Switch to coaching."
5. Close the app fully (swipe it away in the app switcher) and open it again.
- [ ] It opens in the **coach version** (the one used last).
6. Picture → **Switch to rowing**.
- [ ] Back to the rower version. Close and reopen the app: still the **rower version**.
7. Coach version again → picture → **Settings**.
- [ ] Its top row now reads **Switch to rowing** (it offers whichever version you're not in).

## 5. Losing coaching
1. As Piero (owner): **Manage club → yourself → turn Make coach off**.
- [ ] The app goes back to the rower version, and Settings no longer has the switch row.

## What's not in this phase
Boats, the Calendar, availability, races and the Land / Water choice on + come in phases CV2 and
CV3 (`docs/design/coach-version-build-plan.md`). Until then the bar has two tabs, and + sets a workout.

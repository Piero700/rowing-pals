# Coach version — build plan

Started 2026-10-16 on branch `t41-coach-version` (from `t40-coaching-phase2`). Design: the canvas
(docs/design/v4/, version 122) and decisions 67–70 in `v2-decisions.md`. Each phase is tested on the
user's phone before it merges.

## Phase CV1 — the coach's own app (this phase)
- **Which version opens** (`AppMode`, `App/AppShell.swift`): an account its club has made a coach
  opens the coach version if it doesn't row; one that rows and coaches opens the version it used
  last (stored on the phone, rowing until first switched). Everyone else gets the rower app.
- **Coach tab bar** (`App/CoachRootView.swift`): the floating glass pill and the solid + beside it,
  as the rower's. Tabs that exist: **Rowers** and **Workouts** (the old Coaching area, split into two
  tabs with large titles). **Boats** joins in CV3 and **Calendar** in CV2, so the bar never shows an
  empty tab. **+** opens New workout until water sessions exist (CV3 turns it into Land / Water).
- **Headers**: large title; the avatar top right opens the coach's **Profile**; Rowers keeps Squads.
- **Coach Profile** (`CoachProfile` artboard): photo and name, "Coach · club", **Switch to rowing**
  (only for accounts that row), Club (your club, Squads), Account (Settings, Edit profile, Log out).
  Attendance totals joins with CV2.
- **Switching**: Switch to rowing on the coach's Profile; **Switch to coaching** at the top of
  Settings in the rower version (Settings opened from the coach version offers Switch to rowing).
- **Coaching buttons removed** from Your crew and Profile → Club: the switch replaces them.
- **Side** (stroke / bow / both): About you at sign-up and Edit profile, rowers only.
  Server: `docs/migrations/2026-10-16-coach-version.sql` (`profiles.side`).

## Phase CV2 — Calendar and attendance (decisions 68, 69 and the old Phase 3)
Practices (one-off or weekly until a date; edit or cancel one or the series), the coach's
**Calendar** tab (month, a day's items, Take register, Add: practice, land or water session, race
or event), the register, attendance totals and terms, **Who's available**, races and events with
"Can you race?", the rower's **Calendar** tab (Feed · Rankings · Calendar · Profile) with per-session
availability a week ahead and Whole day, practice reminders, and the club's **Week starts on**.

## Phase CV3 — Boats and water sessions (decisions 67, 70)
The **Boats** tab (Sessions · Saved boats), crewing a boat (upright drawing, boat type, stroke- or
bow-rigged, sides, availability in the picker), new water session and sending it, the rower's boat
card on the Feed and its alert, saved boats and Add a boat, and **+** asking Land or Water.

# Coach version — build plan

Started 2026-10-16 on branch `t41-coach-version` (from `t40-coaching-phase2`). Design: the canvas
(docs/design/v4/, version 122) and decisions 67–70 in `v2-decisions.md`. Each phase is tested on the
user's phone before it merges.

## Phase CV1 — the coach's own app (built; waiting on the phone test)
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

## Phase CV2 — Calendar and attendance (decisions 62, 68, 69 and the old Phase 3) — built
Built 2026-10-16; checklist in `docs/testing/coach-version-phase2.md`. Server:
`docs/migrations/2026-10-16-calendar.sql` and the `send-push` function (deployed to staging).
- **Coach bar**: Rowers · Workouts · **Calendar** (Boats slots in before Calendar in CV3).
- **Coach Calendar** (`Features/Calendar/CoachCalendarView.swift`): the month (dots for practices,
  workouts and races), today and tomorrow or the day tapped, each with **Add** (Practice, Land
  session, Race or regatta, Other event; water sessions come with CV3). A practice card shows its
  counts and opens the editor; **Take register** for today and earlier. Who's available sits top
  right; next week's availability and races coming up are below.
- **Practice editor**: what (an addition), date, place, start and end, squads, every week until a
  day, Remind rowers; editing a series asks this one or the rest; Cancel this practice / Cancel
  the whole series.
- **Register**: everyone it's for with what they said and did; rows start on Present (checked in),
  Present + Suggested (posted a session that day), Excused (said can't) or Absent (said available,
  did neither); the last change to a saved mark; Save register.
- **Attendance totals** (coach Profile): This term · 4 weeks · Custom, by squad and by rower lowest
  first; **Edit dates** opens the club's term dates.
- **Who's available**: This week · Next week, each session at a glance, one session's Available
  (with side), Can't (with reasons) and No answer; races coming up.
- **Races and events**: the race page (coach: counts and the three lists, Edit; rower: Can you
  race? with a reason) and the editor (Race or regatta / Other event, days, place, squads, note,
  Ask who can race, Delete).
- **Rower Calendar tab** (Feed · Rankings · Calendar · Profile + Log): this or next week, per
  session and Whole day answers, races; the practice page (answer, reason, Check in, coach's mark);
  the Feed's **next practice** card with Available · Can't.
- **Rowers list attendance** now counts practices; a rower's page has **Attendance · this term**.
- **Week starts on** (Settings → Club · coaches, coaches only): calendars, Who's available and
  coaching's weekly totals follow it.
- **Alerts**: New practice, Practice changed / cancelled, Practice in 2 hours (Settings → Practice
  reminders), and a new race or event; tapping one opens the practice or race.

## Phase CV3 — Boats and water sessions (decisions 67, 70)
The **Boats** tab (Sessions · Saved boats), crewing a boat (upright drawing, boat type, stroke- or
bow-rigged, sides, availability in the picker), new water session and sending it, the rower's boat
card on the Feed and its alert, saved boats and Add a boat, and **+** asking Land or Water.

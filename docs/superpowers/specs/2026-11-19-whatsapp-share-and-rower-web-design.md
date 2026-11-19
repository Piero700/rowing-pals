# WhatsApp share picture and the rower web page — design (decision 110)

Written 19 November 2026. Status: **approved by the user, 19 Nov.** Nothing is built yet.

## Why

Coaches run their squads through WhatsApp groups, and about 4 in 10 interested rowers can't install
Rowing Pals because they don't have an iPhone (`docs/app-analysis-2026-11-03.md`). A coach won't pay
for a tool that only shows part of the squad (market check, 19 Nov). Two pieces fix that together:

1. A coach can post the week's plan, or today's workout, into the squad's WhatsApp group as a picture
   in the app's own style. The picture tells rowers without an iPhone where to answer.
2. A small web page where those rowers sign in, say **Available / Can't** for each practice, answer
   **Can you race?**, and **check in** on the day. Coaches then see them in Who's available and the
   register like anyone else.

Success: a coach with a mixed iPhone/Android squad gets a complete Who's available and register
without chasing anyone on WhatsApp.

## Goals

- **Share to WhatsApp** from the coach's Calendar (a week) and from a workout (one day), as a picture.
- A rower web page at **rowingpals.com/go**: sign up, sign in, join a club, this week and next,
  Available / Can't with a reason, Can you race?, check in.
- Same rules as the iPhone app for everything the web page does (age 13+, who sees what, the check-in
  window), enforced by the database functions that already exist.

## Non-goals (this phase)

- Posting ergs, the Feed, Rankings, PBs or predictions on the web. Photo reading uses Apple's Vision,
  which isn't available in a browser.
- Showing a rower's boat and seat on the web.
- Web push notifications. The WhatsApp picture is the reminder.
- The coach web app for large screens. A later, separate project (estimated 2–3 months) that will
  grow from the same web base.
- A native Android app.
- Automatic sending to WhatsApp (needs Meta's paid business service, approval and phone numbers).

## Anti-goals (would make this a failure even if it works)

- A link that lets anyone answer for a rower without signing in.
- The web page showing other rowers' names, answers or reasons.
- Coaches having to post the plan twice, or rowers having to answer in two places.
- A development or staging web build that talks to the production database.
- Junior protections (decision 107) weaker on the web than in the app.

## Approaches considered

For the message style (user saw mock-ups of all three, 19 Nov):
- **A. Text**: readable, copyable, tappable link; plain.
- **B. Picture in the app's style**: looks like the app and advertises it in every club chat; can't be
  tapped or copied. **Picked by the user.**
- **C. Both**: two sends, because WhatsApp often drops text sent with a picture.

For the web page:
- **A. Plain hand-written pages** hosted with the website: quickest, but messy as it grows and would be
  thrown away for the coach web app.
- **B. A small React web app** (Vite, TypeScript), built to static files and hosted like the website:
  a setup step, but the coach web app grows from the same base. **Picked by the user.**
- A native Android app was ruled out: 3–5 months for far more than these rowers need.

## Part 1 — Share to WhatsApp (iPhone app, coach version)

### Where the button goes
- **Coach Calendar**: a **Share week** action. A sheet asks **Which week** (This week / Next week, from
  the club's Week starts on setting) and **Who for** (Whole club or one squad), shows the picture as a
  preview, and has **Share**, which opens the iPhone Share sheet. WhatsApp is picked there; the app
  doesn't open WhatsApp itself.
- **Who for, one squad** shows exactly what that squad's rowers see on their own Calendar and on the
  web page: practices and events for that squad **and** whole-club ones. *(Claude's call after review:
  the card must match the web page.)*
- **A workout** (the coach's workout page): **Share workout** opens the same sheet with the one-day
  card and no week or squad choice; the workout's own audience names the card.

### What the picture shows
Drawn by a SwiftUI view rendered with `ImageRenderer`, shared with `ShareLink`, as
`Features/Feed/ShareWorkoutSheet.swift` and Season Wrapped already do. Always in the dark palette
(the app's primary design), whatever mode the phone is in, so every rower's copy looks the same. All
values from `DesignSystem/` tokens; numerals `.monospacedDigit()`; no gradients.

**Week card:**
- Title **This week** or **Next week**; under it the squad name (or the club name) and the dates
  ("24–30 Nov").
- One row per session, in time order: day and start time on the left in brand blue; on the right the
  kind and the key detail:
  - land workout: "Erg · 3 × 2k" and a second line with rate and rest targets if set;
  - practice: its title (or "Practice") and its place;
  - water session: "Water" and "meet 06:15" if a meet time is set;
  - race or event: its name and place.
- Cancelled practices are left out.
- **No rowers' names**, crews or seats on the card (it goes into group chats that may include
  juniors and people outside the squad).
- Footer, two lines: **No iPhone? Say if you can make it at rowingpals.com/go** and the Rowing Pals
  wordmark.
- An empty week shows "Nothing planned yet" and still shares.

**Workout card (one day):**
- Day, date and start time; the workout title; each piece with its targets (split, rate, rest) as the
  workout page shows them; the zone if set.
- The same footer.

**The link:** the share also passes `https://rowingpals.com/go` as a second item, so WhatsApp can use
it as the picture's caption. If WhatsApp drops it, the link printed on the card is the one that always
works.

## Part 2 — The rower web page (`web/`, React + Vite + TypeScript)

### Screens (phone-first; must also work on a laptop)
1. **Sign in**: email or username and password, **Continue with Google**, **Create account**,
   **Forgot password**. Reset works exactly as the app's (by email or username,
   `UsernameService.sendReset`, the same 6-digit code and the same email templates). *(Claude's call:
   codes, as the app does, so iPhone users' emails don't change.)*
2. **Create account**: name (the `display_name` the register shows), email, password, **Date of birth** (13+, the same message as the app:
   "Rowing Pals is for people 13 and over."), and agreeing to the Terms and Privacy Policy
   (links to rowingpals.com/terms and /privacy). The date travels in sign-up metadata as the app does.
   If Confirm email is on for that project, the 6-digit code screen follows, as in the app
   (decision 66). The profile row is made the way the app's `ensureProfileExists` makes it.
   **No Sign in with Apple on the web** in this phase: the page is for rowers without an iPhone.
   An Apple-account rower uses the iPhone app. *(Claude's call.)*
3. **Choose a username**: same rules and checks as the app (`username_available`, `set_username`).
4. **Your date of birth**: for Google sign-ins with no date yet, as in the app (decision 107),
  including Change date / Delete my account for under-13s.
5. **Join your club**: enter the club's code (`club_for_invite_code`, `join_club_with_code`) or
   search and join/request (`join_club`). Shows "Waiting for the club to approve you" for approval
   clubs, with Cancel request.
6. **Your week** (the main screen): This week · Next week. Each day lists the rower's practices and
   races:
   - practice: time, title, place, and **Available / Can't**; Can't asks for an optional reason
     ("Only coaches see this"). Calls `respond_practice`.
   - **Check in**: shown from 30 minutes before a practice until it ends (`CalendarRules.canCheckIn`
     rule, enforced again by `check_in_practice`); after it, "Checked in 06:24".
   - race or event: **Can you race?** Yes / No with a reason (`respond_event`).
   - Reads come from `my_practices`, `my_events`, and the rower's own rows in `attendance_responses`
     and `event_responses`.
7. **Account**: username, club, **Leave club**, **Sign out**, **Delete account** (the
   `delete-account` function, with the same confirmation wording as the app).

A coach who signs in sees: "Coach tools are in the iPhone app for now." and can still use their
own rower week if they row.

### Look
The app's palette and type scale ported as CSS variables in one tokens file (`web/src/tokens.css`),
dark first, light following the system; `font-variant-numeric: tabular-nums` everywhere; UK English;
grouped rows (one card per group, 12 pt corners, 44 pt rows) as in decision 99; no gradients.
The page is not glass (Liquid Glass is the iPhone app's requirement).

### Data and security
- **No new tables or policies expected.** Every call above already exists and is used by the app;
  the database already limits a rower to their own answers and their own practices.
- Supabase URL and anon key come from build-time environment files per environment
  (`.env.staging`, `.env.production`), gitignored, never hardcoded. Local development and the
  staging site use the staging project only.
- Supabase Auth: add the web origins (staging and live) to the allowed redirect URLs, and the Google
  sign-in redirect for the web.
- **One server change, found while planning:** the `username-auth` and `delete-account` Edge
  Functions don't answer browsers yet (no CORS headers). They gain them, behaviour otherwise
  unchanged, deployed to staging first and production at launch.

### Which database
**The live page uses the same Supabase project as the App Store app (production); the staging copy
uses the same one as TestFlight (staging).** Otherwise Android rowers wouldn't show up in their
coach's Who's available. So the live `/go` goes up with, or after, the App Store launch
(`docs/production/app-store-launch.md`); until then only the staging copy runs. *(Claude's call after
review.)*

### Hosting
`npm run build` makes static files served at **rowingpals.com/go** on Netlify, the website's planned
host (`website-handoff/.../START-HERE.md`), with a Netlify rewrite sending every `/go/*` address to the
app. A second Netlify site serves the staging copy; its exact address is picked when it's set up and
goes into the Supabase redirect list then. No server.

## Docs to update when built
- `docs/design/v2-decisions.md`: decision 110.
- `CLAUDE.md`: Current focus, and the Stack section gains the web page (React, Vite, TypeScript).
- Website: the Coach section and FAQ mention the web page for rowers without an iPhone.
- Privacy Policy: the web page, and that it uses only the cookies/storage needed to stay signed in.
- Checklist: `docs/testing/whatsapp-share-and-web.md`.

## Left to the builder
- The exact component structure and routing library of the web app.
- Row spacing and wrapping on the cards once real long titles are tried.
- How many sessions fit before the week card needs to grow (it grows; WhatsApp shows tall pictures).
- Unit tests for the web page's pure parts (the check-in window, grouping practices by the
  rower's local day, the week range from Week starts on) and for the iPhone card's row text.

# v2 redesign — decisions

Decided 2026-09-23, resolving the open questions in `rowing-pals-redesign-handoff-v2.md` §6.
These override the prototype wherever they differ. The user can change any of them at any time;
if they do, update this file.

| # | Topic | Decision |
|---|---|---|
| 1 | Posts | Keep the full multi-post feed history. Do **not** copy the prototype's "one live post per user" behaviour. |
| 2 | Prediction / estimate cards (2k, 5k) | Build the card UI. The user has an existing prediction algorithm and will supply it; integrate it when provided. Until then, show the card as an explicit placeholder with no invented numbers. Do not write your own algorithm. |
| 3 | Units | Session and post distances stay in **metres**. Add a metres/km toggle **for leaderboard totals only** (weekly/monthly/yearly volume gets large). Storage stays whole metres (`distance_m`); conversion happens at the view layer. |
| 4 | CSV export | Not wanted. Omit the "Export your metres" row. Everything stays in the app. |
| 5 | Palette | Adopt the four-accent-role palette (brand / records / rank / success) as in CLAUDE.md. |
| 6 | Private accounts and follow requests | Build them, as an **early phase** (schema: `profiles.is_private` plus follow-request status; review every place `follows` is read). |
| 7 | Clubs | Build as in the prototype: create club, join policy (open / approval / invite), roles (owner / co-owner / admin / member), join requests, owner-only management. Supersedes the "club model open question" note. |

**Resolved:** redesign Phase B (commit `e47755c`) built the metres/km toggle app-wide; commit
`903698c` narrowed it to the Volume leaderboard only, per decision 3.

Other prototype items are placeholders and need the user's go-ahead before building: quiet hours,
"Who can comment", the demo-data seeding button (dev-only, never ship).

## Photos, lead piece and PB posts (decided 2026-09-25)

| # | Topic | Decision |
|---|---|---|
| 8 | Adding photos | One "Add photo" action offering **Take photo** or **Choose from library**. Every added photo is run through OCR. |
| 9 | Monitor vs environment photo | **Detected automatically, never asked.** If OCR finds erg-monitor readings, the photo becomes a piece (editable row, metres added to the session total). Otherwise it is an environment photo (shown in the gallery, not read). The rower can correct a wrong guess without being prompted. |
| 10 | Lead piece on the feed | The **most intense** piece leads the post — proposed rule: fastest average split among the session's pieces. Warm-up/cool-down never lead. 30/60-minute UT2 pieces are ordinary training, not "PB attempts". |
| 11 | Feed photos | Swipeable, Instagram-style carousel: lead piece's monitor photo first, then the other pieces, then environment photos. |
| 12 | New PB | Only an **actual** new PB (beats the previous best) is highlighted: the post gets an attention-grabbing animated glow (RGB-LED style). Needs its own design token(s) and a Reduce Motion fallback (static glow). |

## v3 design conflicts (decided 2026-09-25)

| # | Topic | Decision |
|---|---|---|
| 13 | Font | **Keep SF Pro.** v3's Inter is not used; v3 sizes, weights and tracking still apply. |
| 14 | App icon | **No app-icon section at all** in Settings for now — no icon changes. |
| 15 | CSV export | Still **no export** (decision 4 stands over v3's "Export CSV" row). |
| 16 | Feed numbers | The feed card's Distance / Time / /500m trio shows the **lead piece's own** numbers (decision 10's most intense piece), not the session totals. |

## v3 Rankings (decided 2026-09-26)

| # | Topic | Decision |
|---|---|---|
| 17 | Rankings scope | **My club / Following only** — v3's "All" (app-wide) is not added; the global-scope cancellation stands. |
| 18 | Rankings period and source | Keep **Week / Month / Year** and **All / Erg / Water** alongside v3's layout; the hero card names the chosen period. |

## Push notifications (decided 2026-09-26)

| # | Topic | Decision |
|---|---|---|
| 19 | Notifications | **Built now, delivered once the paid Apple Developer Program is joined** (free accounts can't use push; the user chose "build now, enrol later"). v3 Settings' three switches plus Quiet hours, saved per rower in `notification_settings`. **Comments and replies**: a comment on your post, or on a post you've commented on (comments have no separate reply). **Personal bests**: your own new PB, and a new PB by someone you follow ("you or a friend"). **Club activity**: a clubmate posts; off by default, as in v3. Every alert obeys the feed's rules (blocks, private accounts, post visibility). **Quiet hours** (default 22:00–06:30, on the rower's own clock, editable in a sheet): alerts still arrive but silently, no sound and screen stays dark, waiting in Notification Centre. Tapping an alert opens the post above whatever is on screen. Server: triggers in `docs/migrations/2026-09-26-notifications.sql`, the `send-push` Edge Function, one database webhook; setup and tests in `docs/testing/notifications.md`. |

## Another rower's profile, v3 §08 (decided 2026-09-29)

| # | Topic | Decision |
|---|---|---|
| 20 | Their ranks | v3's "Overall rankings" and "volume ranking" become their place **within their own club**: this week's ranked metres, best 2k and best 5k, every gender and level — the same rules as the Rankings screen's club board. The card is titled **"Club rankings"** (not "Overall", as app-wide rankings are dropped — decision 17). Equal results share a place; no result shows a dash; rowers with no club show no rankings card. |
| 21 | Their PB tiles | **All-time bests**, labelled "Personal best" — not v3's "Season best". Tiles are v3's 2,000 METRES and 30 MINUTES; tapping opens their PB history. |
| 22 | Layout | **v3 §08 exactly**: header, identity (club, then Public/Private profile), full-width Follow, counts, "Volume · This week" (metres, volume ranking, sessions, streak days), personal bests, club rankings. No tabs, weekly chart, consistency grid or posts grid for other rowers; their posts are reached from the feed. |

## PB history and All personal bests, v3 §10–11 (built 2026-09-29)

| # | Topic | Decision |
|---|---|---|
| 23 | PB history chart and list | Follows v3 §10: the chart is **"PB progression"** and the list **"Personal best history"** — only results that were a PB when set (the old screen charted and listed every result). The axis runs as v3 draws it, **bigger values higher up**: a time chart reads "Lower is faster" (faster 2ks sit lower), a timed test "Higher is further". This replaces task 15's flipped time axis. The chart is tapped, not dragged, so the page still scrolls over it; the slider and prev/next step through results. The "1:34.5 faster" pill is the current PB against the **first** PB. The estimate card shows on your own 2k/5k only (decision 2 placeholder). "View all ›" on your profile opens v3 §11's All personal bests screen; the PBs tab stays. |

## Onboarding, v3 §01 (decided 2026-09-29)

| # | Topic | Decision |
|---|---|---|
| 24 | Onboarding | Step one is v3 §01 exactly (crest rows, "I'm not in a club", sticky "Continue with <club>"; the join-policy text arrives with Clubs, phase G). Step two, **"About you"** (gender and level, **asked of everyone** — changed 2026-10-04 from "level only with a club" so that joining a club later never has to ask), follows it — v3 leaves them out but the test leaderboards need gender; the name comes from sign-up. **A club is optional**: "I'm not in a club" finishes onboarding without one (`profiles.onboarded_at`, `docs/migrations/2026-09-29-onboarding.sql`). A rower with no club sees "You're not in a club" with **Find a club** on the feed's Club tab and the My club rankings; picking one there joins (or asks to join) straight away — no level step — and reloads the feed, rankings and profile. The old "Create a club" / "Invite code" buttons are gone until phase G. |

## Clubs, v3 §12 and phase G (decided 2026-09-29)

| # | Topic | Decision |
|---|---|---|
| 25 | Clubs | **Hub** "Your crew" is v3 §12 (club name, Find a club to join, Create a club, Continue without a club), plus your role, **Manage club** for admins and up, a pending request you can cancel and invitations to accept. **Roles are tiered**: admins answer join requests, invite and remove members; co-owners also change roles and edit the club; the owner can do everything, including making co-owners. Nobody changes or removes someone at or above their own role. **Joining**: open clubs join at once; approval clubs send a request (one pending at a time); invitation-only clubs need an **in-app invite** (Invite a rower) **or the club's invite code** ("Have an invite code?"). **Owners** can't leave or switch clubs until they **hand over ownership** (they stay on as co-owner) or **delete the club** (everyone in it is left club-less; sessions and metres stay theirs). Membership changes only through server functions (`docs/migrations/2026-09-30-clubs.sql`); a trigger blocks any other change. **Club directory**: every UK university and college boat club and the UK's established membership clubs (302, `docs/migrations/2026-09-30-club-directory.sql`), open and unowned; the early placeholder clubs are removed while empty; the user owns UEA Boat Club. |
| 26 | Club follow-ups (user notes, 2026-10-04) | **One club at a time**: in a club, Your crew shows the club (details, your role) and **every other member** under "Crewmates · N" — not yourself (user, 2026-10-04) — each opening their profile, with **Leave club** as the only way out (owners hand over or delete in Manage club); the find/create buttons appear only without a club. **Requests**: after asking, the button reads **Requested** (greyed) with **Refresh**; a declined request stays visible as **"You weren't accepted to <club>"** with **Request again**; when accepted while waiting, the club screen closes back to where you started. **Invitations**: the invited rower gets an alert (push, once enabled) that opens Your crew, and the invitation also shows on their Profile; a declined invitation shows as **"Declined the invitation"** in Manage club, with Invite again. **Live updates**: club pages refresh themselves through Supabase Realtime, plus on returning to the app and by pull to refresh. A membership change made elsewhere (an admin accepts, removes or promotes you) also reloads Feed, Rankings and Profile (`MembershipMonitor`), and while a request waits the Feed says "Request sent to <club>". Server: `docs/migrations/2026-10-04-club-updates.sql`. |
| 27 | Tapping the tab you're on (user, 2026-10-04) | Tapping **Feed**, **Rankings** or **Profile** while that tab is already showing scrolls it to the top, then refreshes it, with a small spinner under the header while it reloads. The scroll finishes before the reload starts (starting both at once cancelled the scroll and hid the tab bar on a phone). `FloatingTabBar.onReselect` → `scrollsToTopOnReselect` in `DesignSystem/ReselectScrollModifier.swift`. |
| 28 | Custom tests are club tests (user, 2026-10-04) | A club's **admins and up** add tests for their club under Rankings → Test results (the handoff's trailing **"+ Add test"** tile): a distance in whole metres (100–100,000), or a time typed in **minutes or seconds** (10 seconds to 120 minutes; seconds added 2026-10-05, e.g. a 30-second test). The name is made from it in the standard tiles' style — **750m, 3k, 1500m, 20min, 30s** (not the prototype's "20 min", to match the existing 4min/30min/60min tiles); a whole number of minutes is named in minutes, so 120 seconds and 2min are one test. Timed pieces may stop 2 s or 1% from the target, whichever is bigger, but never more than 5% (1.5 s on a 30s test). A standard test or a test the club already has can't be added. **Every member** sees the club's tests after the nine standard ones, can pick one as the Session type when posting (same exact-distance / time-within-tolerance check), and each has its own leaderboard, scored fastest time or furthest distance. Admins and up can **delete** a test from its board, which removes its results. Club results never appear in profile PBs or club rankings. Server: `docs/migrations/2026-10-04-club-tests.sql`. |
| 29 | Profile pictures (user, 2026-10-05) | Tap **your own picture on Profile** (it carries a small camera badge) → **Take photo** (front camera first) or **Choose from library**, both with iOS's square move-and-scale; **Remove photo** when you have one. The picture is checked like posted photos, squared to 600 px, stored in a private `avatars` bucket and shown in **every avatar in the app** (feed, rankings, crew and member lists, comments, people lists) via `AvatarStore`; without one, initials as before. Visibility follows the photo rule: a private account's picture shows only to its approved followers. Server: `docs/migrations/2026-10-05-seconds-tests-and-avatars.sql`. |
| 30 | Pace Engine inputs and outputs (user, 2026-10-05) | Replaces "no weight class anywhere". **No weight classes or age groups in any ranking.** Bodyweight and age are private inputs to the prediction algorithm only: never shown on a profile, never visible to other rowers (stored apart from the public profile row). The engine's **weight-adjusted** and **age-graded** scores are **not shown anywhere**. The **Population Estimate** (cold start from age/sex/weight seed values) stays **off** until its seed values are replaced with data fitted from the Concept2 rankings (SPEC.md §7.6) — Claude's call, as the handoff says no user should see the unfitted numbers; until then a rower with no history sees the Insufficient Data state. Note: with that off, profile age and weight don't change any prediction yet — the engine anchors on the rower's own sessions, and uses demographics only for the cold-start estimate. |

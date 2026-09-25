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

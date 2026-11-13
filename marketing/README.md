# Rowing Pals — marketing

| Folder | What it is | Where it goes |
|---|---|---|
| `website/` | rowingpals.com — static pages (home, `/privacy`, `/terms`, `/support`), no build step | Upload the folder as the site root (Netlify, Vercel, GitHub Pages, Cloudflare Pages…) |
| `emails/` | Confirm signup + Reset password | Supabase → Authentication → Email Templates (subject lines are in each file's top comment) |
| `app-store/` | 10 screenshots (1290×2796) + 3 banners | App Store Connect; `export/` holds the PNGs |

**No pricing on the site for now** (user, 2026-11-06). The launch message is "Coming to the App Store
later this month": in the hero pill, the FAQ, the Launch section and the page's `description` and
`og:description` in `website/index.html`. Change all of them when the app is out or the date moves.

**Phone mockups** on the site and in the App Store art come from the same code:
`website/assets/ui.js` + `ui.css`. Edit a screen there, then re-export the art:

```bash
./marketing/app-store/render.sh
```

That also refreshes `website/assets/og.png` (the link preview image).

**App Store screenshots**, in upload order (Apple allows 10 per device; the list is `ART` in `app-store/artwork.html` and the `for` loop in `render.sh`, so change both):

| # | File | Caption | Screen |
|---|---|---|---|
| 1 | `01-proven` | Every metre. Proven. | `feed` |
| 2 | `02-capture` | Two cameras. One shot. | `capture` |
| 3 | `03-numbers` | We read the numbers. | `review` |
| 4 | `04-rankings` | Climb the rankings. | `rankings` |
| 5 | `05-challenges` | Turn the winter into a contest. | `challenges` |
| 6 | `06-pbs` | PBs worth celebrating. | `pb` |
| 7 | `07-your-boat` | Your boat. Your seat. | `yourBoat` |
| 8 | `08-coach-rowers` | Know every rower. | `coachRowers` |
| 9 | `09-coach-notepad` | Write down the scores. | `coachNotepad` |
| 10 | `10-coach-boats` | Crew boats in seconds. | `coachBoat` |

Left out to stay at 10: `profile`, `coachWorkout` and `coachCal`, which remain in `ui.js` if you want to swap one in. The art follows decision 100 (solid colours, no gradients or blurred glows) and states no prices.

Before launch:
- When the app is live, add Apple's official "Download on the App Store" badge with the real link.
- `website/privacy/` and `website/terms/` copy the app's `PrivacyPolicyView.swift` and `TermsOfServiceView.swift` word for word. When one changes, change the other. Use `https://rowingpals.com/privacy` and `https://rowingpals.com/support` in App Store Connect.
- The emails load the logo from `https://rowingpals.com/assets/icon-256.png`, so deploy the site first.
- Mockup names, clubs and numbers are fictional sample data. The mockups follow the app as of 2026-11-06.

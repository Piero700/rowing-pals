# Rowing Pals — marketing

| Folder | What it is | Where it goes |
|---|---|---|
| `website/` | rowingpals.com — one static page, no build step | Upload the folder as the site root (Netlify, Vercel, GitHub Pages, Cloudflare Pages…) |
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

Before launch:
- When the app is live, add Apple's official "Download on the App Store" badge with the real link.
- `/privacy` and `/terms` in the footer need real pages (the App Store requires a public privacy policy URL).
- The emails load the logo from `https://rowingpals.com/assets/icon-256.png`, so deploy the site first.
- Mockup names, clubs and numbers are fictional sample data. The mockups follow the app as of 2026-11-06.
- The App Store art in `app-store/export/` predates the 2026-11-06 site update. Re-running `render.sh` uses the new mockups but `artwork.html` still needs its own restyle (gradient headlines, the coach promo's boat).

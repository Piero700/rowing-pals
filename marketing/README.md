# Rowing Pals — marketing

| Folder | What it is | Where it goes |
|---|---|---|
| `website/` | rowingpals.com — one static page, no build step | Upload the folder as the site root (Netlify, Vercel, GitHub Pages, Cloudflare Pages…) |
| `emails/` | Confirm signup + Reset password | Supabase → Authentication → Email Templates (subject lines are in each file's top comment) |
| `app-store/` | 10 screenshots (1290×2796) + 3 banners | App Store Connect; `export/` holds the PNGs |

**Coach price is a placeholder** (£9.99/month, £99.99/year). Change it in one place:
`PRICES` at the top of `website/assets/site.js`. Screenshots and banners don't show a price.

**Phone mockups** on the site and in the App Store art come from the same code:
`website/assets/ui.js` + `ui.css`. Edit a screen there, then re-export the art:

```bash
./marketing/app-store/render.sh
```

That also refreshes `website/assets/og.png` (the link preview image).

Before launch:
- Swap the home-made "Download on the App Store" buttons for Apple's official badge and add the real App Store link (`href="#"` / `#download` in `website/index.html`).
- `/privacy` and `/terms` in the footer need real pages (the App Store requires a public privacy policy URL).
- The emails load the logo from `https://rowingpals.com/assets/icon-256.png`, so deploy the site first.
- Mockup names and numbers are the sample data from `docs/design-brief.md`.

# Minimum age 13: phone test checklist

Decision 107 in `docs/design/v2-decisions.md`.

## 1. The database change (staging)

**Done 17 Nov 2026 (by Claude):** `docs/migrations/2026-11-17-minimum-age.sql` is run on staging.
Checked there: a date of birth under 13 is refused; a junior's first date of birth makes the account
private; a coach sees a junior's date of birth but not their weight until "Parent or guardian agrees"
is on; a date of birth can't be removed; coaches can no longer read the table directly. Skip to
section 2. The steps below are for production later.

1. Go to **supabase.com**, sign in, and open the **production** project.
2. Click **SQL Editor** in the left bar, then **+ New query**.
3. In Finder, open `Rowing Pals/docs/migrations/2026-11-17-minimum-age.sql`, select everything (**⌘A**),
   copy (**⌘C**), and paste it into the query box (**⌘V**).
4. Click **Run** (bottom right).
   - [ ] It finishes with "Success. No rows returned".

## 2. Install the build

From Xcode: plug the iPhone in, choose it at the top of the Xcode window, and press **▶ Run**.

## 3. Your own account (already signed in)

1. Open the app.
   - [ ] **Your date of birth** appears before anything else (if you'd never added one in Edit profile).
   - [ ] **Continue** stays grey until you move the date wheels.
2. Pick your real date of birth and tap **Continue**.
   - [ ] The app opens as normal.
3. Close the app fully (swipe it away) and open it again.
   - [ ] It isn't asked again.
4. **Profile → ⚙︎ → Edit profile**.
   - [ ] **Date of birth** shows your date, with no ✕ to remove it.
   - [ ] The date picker won't go later than 13 years ago today.

## 4. Under 13 (use a spare test account, not your own — it gets deleted)

1. Sign in to a spare test account that has never given a date of birth.
2. On **Your date of birth**, pick a year that makes it under 13 (for example 2015) and tap **Continue**.
   - [ ] "Rowing Pals is for people 13 and over." appears with **Change date** and **Delete my account**.
3. Tap **Change date**.
   - [ ] You're back on the wheels, nothing deleted.
4. Tap **Continue** again, then **Delete my account**.
   - [ ] You're signed out and back on the sign-in screen; that account can't sign in any more.

## 5. Signing up

1. Sign out, then tap **New here? Create an account**.
   - [ ] A **Date of birth** row with **Add** sits under the username.
2. Tap **Add**, set a date under 13.
   - [ ] "Rowing Pals is for people 13 and over." shows under it in red, and **Sign up** stays grey.
3. Set a date that makes you 15, fill in the rest with a spare email, and sign up.
4. Enter the code from the email.
   - [ ] The app opens without asking for the date of birth again.
   - [ ] **Settings → Privacy → Profile visibility** says **Private**.
   - [ ] **Settings → Logging → Selfie with each session** is **off**.

## 6. Junior bodyweight and coaches (the 15-year-old account from section 5)

1. **Edit profile** → enter a **Weight**.
   - [ ] A **Parent or guardian agrees** switch shows under Weight (only for under 18s).
2. Join a club that has a coach, and on the coach's account open this rower.
   - [ ] Their weight (and watts per kilo) isn't shown.
3. Back on the junior: turn **Parent or guardian agrees** on and tap **Save**.
4. On the coach's account, open the rower again.
   - [ ] Their weight shows.

## 7. The wording

1. **Settings → Terms of Service**.
   - [ ] It starts with **Who can use Rowing Pals**.
2. **Settings → Privacy Policy**.
   - [ ] It has **Children and young people**.

## 8. Publish the website pages

The website's Terms and Privacy pages (`marketing/website/terms` and `/privacy`) have the same new
wording. To publish them:

1. Open your website host's dashboard (wherever rowingpals.com is hosted — Netlify, Vercel, GitHub
   Pages or Cloudflare Pages; see `marketing/README.md`).
2. Upload the whole `marketing/website` folder as the site, the same way as last time.
3. Open **rowingpals.com/terms** in a browser.
   - [ ] It starts with **Who can use Rowing Pals**.
4. Open **rowingpals.com/privacy**.
   - [ ] It has **Children and young people**.

## 9. App Store age rating

When you set up the App Store listing: **App Store Connect → Apps → Rowing Pals Beta → App
Information → Age Rating → Edit**. Answer the questions honestly (users post photos and comments to
each other). With user posts it will most likely come out at 13+ or higher.

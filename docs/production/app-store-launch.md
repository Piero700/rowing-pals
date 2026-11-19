# Putting Rowing Pals on the App Store

Written 2026-11-19. Do the sections in order: each one needs the one before it.
Tick each box as you go. Where it says **(Claude)**, tell Claude you've reached that step and it does it.

What's already done in the code (2026-11-19):
- `Rowing Pals/PrivacyInfo.xcprivacy`, the privacy manifest Apple requires. It matches section 5.
- Photo filtering switched on: the app now asks for Apple's **Sensitive Content Analysis**
  capability, so nude photos are blocked before they upload (App Store rule 1.2) on any phone
  where the person has turned on Settings → Privacy & Security → Sensitive Content Warning.
- `docs/production/production-setup.sql`: the whole database in one file, for the new project.
  Made by `scripts/build-production-sql.sh` from `docs/schema.sql` + every later migration.

---

## 1. Before you start: finish testing on staging

- [ ] Phone checklists still open: `docs/testing/automatic-leaderboards.md`,
      `docs/testing/predictions-every-post.md`, `docs/testing/private-posts.md`,
      `docs/testing/minimum-age.md`.
- [ ] Upload the website (`marketing/website/`) with the updated Terms and Privacy pages. Open
      https://rowingpals.com/privacy, https://rowingpals.com/terms and https://rowingpals.com/support
      in Safari: all three must load. Apple checks them.
- [ ] Send an email to support@rowingpals.com from another address and check it arrives.

## 2. The production database (about 45 minutes)

### Step 1. Make the project
1. Go to https://supabase.com/dashboard and sign in.
2. Click **New project** (top right).
3. **Organization:** the same one as Rowing-Pals-Dev. **Name:** `Rowing-Pals-Prod`.
4. **Database password:** click **Generate a password**, then **Copy**, and save it in your password
   manager under "Rowing Pals production database". You'll rarely need it, and nobody can show it again.
5. **Region:** **West EU (Ireland)**, the same as staging.
6. Click **Create new project**. Wait until the status says the project is ready (1–2 minutes).

### Step 2. Build the database
1. In the left sidebar click **SQL Editor** (the `>_` icon).
2. Click **+ New query** (or the **+** at the top of the list).
3. Copy the whole setup file. In Terminal:
   ```bash
   pbcopy < ~/Documents/"Rowing app"/"Rowing Pals"/docs/production/production-setup.sql
   ```
   Click into the editor and press **Cmd + V**.
4. Click **Run** (bottom right), or press **Cmd + Return**. If Supabase warns about
   "destructive operations", click **Run this query**. It takes up to a minute.
5. **Expect:** "Success. No rows returned." If you see a red error instead, don't run it again.
   Copy the whole error message (and the line number, if it shows one) and paste it to Claude.
   Each part of the file runs on its own, so Claude can tell you exactly which part to run next.
6. Check it worked. Click **+ New query**, paste this, and click **Run**:
   ```sql
   select count(*) as tables from information_schema.tables where table_schema = 'public';
   select id from storage.buckets order by id;
   ```
   **Expect:** about 60 tables, and the buckets `avatars`, `monitors`, `selfies`.

### Step 3. Sign-in settings (copy staging's)
Open staging (Rowing-Pals-Dev) in a second browser tab so you can copy each setting across.
1. **Authentication** (left bar) → **Sign In / Providers**.
   - **Email:** Enable email provider **on**. **Confirm email** **on** for the public app (anyone
     can sign up, so emails should be real). Click **Save**.
   - **Apple:** turn **on**. **Client IDs:** `rowingpals.Rowing-Pals` (the App Store app). Leave
     the secret fields empty. Click **Save**.
   - **Google:** turn **on**. Paste the same **Client ID** and **Client secret** as staging's
     Google page. Click **Save**. Copy the **Callback URL** shown on this page.
2. In https://console.cloud.google.com → project **Rowing Pals** → **APIs & Services** →
   **Credentials** → click the **Supabase** OAuth client → under **Authorised redirect URIs** click
   **+ Add URI** and paste the callback URL from step 1 → **Save**.
3. Still in Google: **OAuth consent screen** → **Audience** → **Publish app** → **Confirm**. While it
   says "Testing", only your test users can sign in with Google.
4. Back in Supabase: **Authentication** → **URL Configuration** → **Redirect URLs** →
   **Add URL** → `rowingpals://auth-callback` → **Save**.
5. **Authentication** → **Emails** → **SMTP Settings**. Turn on **Enable custom SMTP**. Copy every
   field from staging's SMTP page (the Resend host, port, username, sender `noreply@rowingpals.com`,
   sender name). For the password, use the same Resend API key staging uses (it's in your
   Resend dashboard). Click **Save**.
6. **Authentication** → **Emails** → **Templates**: for **Confirm signup** and **Reset password**,
   paste the HTML from the two files below (subject lines are in each file's top comment). Copy each
   one in Terminal, then **Cmd + V** into the template's body:
   ```bash
   pbcopy < ~/Documents/"Rowing app"/"Rowing Pals"/marketing/emails/confirm-account.html
   ```
   ```bash
   pbcopy < ~/Documents/"Rowing app"/"Rowing Pals"/marketing/emails/reset-password.html
   ```

### Step 4. Server functions and push notifications
1. **(Claude)** Tell Claude "production project is made". Claude deploys `delete-account`,
   `send-push` and `username-auth` to it with the Supabase command line.
2. Set the push secrets: **Edge Functions** (left bar) → **Secrets** (or **Manage secrets**). Add
   `APNS_KEY_ID`, `APNS_TEAM_ID` and `APNS_PRIVATE_KEY` with the same values as staging's. Click
   **Save**. (Staging shows the names but not the values. If you didn't keep the `.p8` key file,
   make a new key: developer.apple.com → **Certificates, IDs & Profiles** → **Keys** → **+**, tick
   **Apple Push Notifications service**.)
3. Make the webhook that sends each alert, exactly as in `docs/testing/notifications.md`, section 2,
   but on the production project.

### Step 5. Connect the app to production
1. Supabase → production project → **Project Settings** (cog, bottom left) → **API** (or **Data API**).
2. Copy the **Project URL** and the **anon public** key.
3. **(Claude)** Paste both to Claude. Claude puts them in `Release.xcconfig`, which is never
   committed, and checks a Release build.

## 3. The App Store record (about 20 minutes)

The beta app "Rowing Pals Beta" is a different app (`rowingpals.Rowing-Pals.beta`). The App Store
app needs its own record.
1. Go to https://appstoreconnect.apple.com → **Apps** → the blue **+** (top left) → **New App**.
2. **Platforms:** iOS. **Name:** `Rowing Pals` (if it's taken, try `Rowing Pals: Erg Log`).
   **Primary language:** English (U.K.). **Bundle ID:** pick `rowingpals.Rowing-Pals`.
   If it isn't in the list, open Xcode → **Rowing Pals** target → **Signing & Capabilities** →
   **Release** tab, and let automatic signing register it (it shows the ID with no red error). Then
   come back and reload the page.
   **SKU:** `rowingpals-ios`. **User Access:** Full Access. Click **Create**.
3. Left side → **App Information**:
   - **Category:** Primary **Health & Fitness**, secondary **Social Networking**.
   - **Content Rights:** "Yes, it contains, shows, or accesses third-party content", and confirm you
     have the rights (people post their own photos).
   - **Age Rating** → **Edit**: answer honestly. Expect to say yes to **User-generated content**.
     The result should be 13+ or higher, which matches the app's minimum age.
4. Left side → **Pricing and Availability**: **Free**. Choose the countries (start with the UK if
   you want a quiet launch).

## 4. Try the App Store version on your phone, then upload it

1. In Xcode, open **Signing & Capabilities** for the **Rowing Pals** target. You should now see
   **Sensitive Content Analysis** listed next to Sign in with Apple and Push Notifications. If it shows
   a red error, click **Try Again**: automatic signing adds it to the app's ID.
2. **Try it first.** Menu **Product** → **Scheme** → **Edit Scheme…** → **Run** (left) → **Info**
   tab → **Build Configuration:** **Release** → **Close**. Plug in your iPhone, pick it at the top,
   and press **Cmd + R**. The app called **Rowing Pals** (not RP Beta) installs, talking to the
   production database. Sign up with your own account, post a session, and check the feed.
   Then set **Build Configuration** back to **Debug** the same way.
3. **Make yourself admin** (for club verification). In the production SQL Editor run:
   ```sql
   insert into app_admins (user_id)
   select id from profiles where username = 'piero';
   ```
   Change `'piero'` if you picked another username.
4. Click the **Rowing Pals** target → **General** → **Identity**. Set **Version** to `1.0` and
   **Build** to `5` (the beta has used 1 to 4, and Apple won't take a number it has already seen).
5. At the top of the window choose the scheme **Rowing Pals** and the device **Any iOS Device (arm64)**.
6. Menu **Product** → **Archive**. Wait for the **Organizer** window to open with the new archive
   selected.
7. Click **Distribute App** → **App Store Connect** → **Distribute**. Leave every option as it is.
   Wait for "Uploaded".
8. In App Store Connect the build shows up after 10–30 minutes (it says "Processing" first). If
   Apple emails about a problem, paste the email to Claude.

## 5. App Privacy answers

App Store Connect → the app → **App Privacy** (left side) → **Get Started**.
- **Do you or your third-party partners collect data from this app?** **Yes.**
- Tick these types, and nothing else:

| Section | Type | Why the app has it |
|---|---|---|
| Contact Info | **Email Address** | Signing in |
| Contact Info | **Name** | Display name and username |
| Health & Fitness | **Health** | Bodyweight, if a rower adds it |
| Health & Fitness | **Fitness** | Erg sessions: distance, time, split, rate |
| User Content | **Photos or Videos** | Monitor photos, selfies, profile pictures |
| User Content | **Other User Content** | Captions, comments, reactions, coach notes |
| Identifiers | **User ID** | The account id |
| Other Data | **Other Data Types** | Date of birth (minimum age) and gender (leaderboards) |

- For **every** type, answer:
  - Used for: **App Functionality** only.
  - **Linked to the user's identity?** **Yes.**
  - **Used for tracking?** **No.**
- Click **Publish** (top right).

If the app ever starts collecting something new, change this page and
`Rowing Pals/PrivacyInfo.xcprivacy` together.

## 6. The listing (App Store Connect → the app → **1.0 Prepare for Submission**)

- [ ] **Screenshots → iPhone 6.9" Display:** drag in the ten PNGs from
      `marketing/app-store/export/` (`01-proven.png` … `10-coach-boats.png`), in that order.
      They're 1290 × 2796, which Apple accepts for 6.9". Skip iPad: the app is iPhone only.
- [ ] **Promotional Text** (170 characters, can change any time without review).
- [ ] **Description** and **Keywords** (100 characters, comma-separated, no spaces). Ask Claude
      to draft both from `marketing/website/index.html` if you want.
- [ ] **Support URL:** `https://rowingpals.com/support`. **Marketing URL:** `https://rowingpals.com`.
- [ ] **App Information → Privacy Policy URL:** `https://rowingpals.com/privacy`.
- [ ] **Copyright:** `2026 Piero Ciobanu`.
- [ ] **Build:** click **+** and pick build 5.

## 7. The review account (Apple's reviewer must see a working app)

A reviewer who signs in to an empty feed and empty rankings often rejects the app as "incomplete".
1. On your phone, with the production app from section 4 step 2, make a demo account: username
   `appreview`, with a password your password manager generates.
2. Use it to post three or four erg sessions (real monitor photos), join your club, and comment on
   a post from your own account so the feed and rankings have something in them.
3. App Store Connect → **1.0 Prepare for Submission** → **App Review Information**:
   - **Sign-in required:** on. Type the demo username and password.
   - **Contact:** your name, phone and email.
   - **Notes:** paste this:
     > Rowing Pals logs indoor rowing machine (erg) sessions. To post, tap Log and take a photo of a
     > rowing machine's monitor; the numbers are read on the device. Without a machine, the demo
     > account already has sessions in the Feed, Profile and Rankings. Every post and comment has
     > Report in its ⋯ menu; people can be blocked from their profile; photos are checked with
     > Apple's Sensitive Content Analysis before upload, and captions and comments are filtered.
     > Accounts can be deleted in Settings → Delete account. Minimum age is 13.

## 8. Submit

1. Top right of the version page: **Add for Review** → **Submit to App Review**.
2. Review usually takes 1–2 days. You'll get an email either way.
3. If it's rejected, paste the whole message from **App Review** (Resolution Center) to Claude.
4. When it's approved: release it (or let it release automatically, if you picked that), then update
   the website's "Coming to the App Store" lines and add the App Store badge (`marketing/README.md`,
   "Before launch").

---

## Keeping production in step later

Every new database change is now run **twice**: on staging first, then on production once the build
that needs it is going to the App Store. After writing a new migration, add it to `MIGRATIONS` in
`scripts/build-production-sql.sh` and run:
```bash
zsh scripts/build-production-sql.sh
```
(That file is for a brand-new project only. For a project that's already set up, run just the new
migration file.)

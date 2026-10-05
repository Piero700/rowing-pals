# Push notifications — setup and test checklist

Decision 19 in `docs/design/v2-decisions.md`. Run against the **staging** Supabase project
(Rowing-Pals-Dev). Tick each box; anything that doesn't match "Expect" is a bug — note the step.

**What works before the paid Apple Developer Program:** everything except the alert actually
arriving on a phone — the Settings switches and Quiet hours save, the server decides who should be
told and records it. **What needs it:** Apple only lets paid accounts send pushes (Part 3).

## Cast

- **A** — your real account, on your phone.
- **B** — your second test account from the phase E tests, on a simulator (see
  `phase-e-private-accounts.md` → "Set up B on a second simulator"). B should follow A and be in
  A's club.

Start every test comment with **TEST** so they're easy to clear afterwards (the app can't delete
comments yet — that comes with phase J).

## Part 1 — One-time setup (do this now)

### 1. Run the migration
1. Open **supabase.com**, sign in, and open the **Rowing-Pals-Dev** project.
2. In the left sidebar click **SQL Editor**, then **+ New query** (top left of the editor).
3. In Finder, open `docs/migrations/2026-09-26-notifications.sql` (in the project folder) with
   TextEdit, press **Cmd + A**, **Cmd + C**.
4. Click in the empty query box in Supabase, press **Cmd + V**, then click **Run** (bottom right).
5. Expect: **Success. No rows returned.**

### 2. Create the webhook that sends each alert
1. In the left sidebar click **Integrations**, then **Database Webhooks**. (On an older dashboard:
   **Database** → **Webhooks**.) If you see an **Enable webhooks** button, click it first.
2. Click **Create a new hook** (top right).
3. Fill in:
   - **Name:** `send_push`
   - **Table:** choose `notifications`
   - **Events:** tick **Insert** only (untick Update and Delete if ticked)
   - **Type of webhook:** choose **Supabase Edge Functions**
   - **Method:** `POST` · **Edge Function:** choose `send-push` · **Timeout:** `5000`
4. Under **HTTP Headers**, click **Add auth header with service key**. (Supabase fills in the
   `Authorization` header itself — you never see or copy the key.)
5. Click **Create webhook** (bottom right). Expect: `send_push` listed.

## Part 2 — Test now (before the paid account)

### 3. Permission and Settings (A, phone)
Install the build from branch `t26-notifications`: open the project in Xcode, choose your iPhone
in the top bar, press **Cmd + R**.
- [ ] Right after the app opens, iOS asks **"Would Like to Send You Notifications"**. Tap **Allow**.
- [ ] **Profile → ⚙︎ Settings**. Expect a **Notifications** section between Units and Privacy:
      Comments and replies **on**, Personal bests **on**, Club activity **off** with
      "New posts from *your club*". No Quiet hours row (removed by decision 36). No red error.
- [ ] Turn **Club activity** on. Close Settings, fully close the app (swipe it away), reopen,
      go back to Settings. Expect: still on.
- [ ] iPhone **Settings** app → **Notifications** → **RP Dev** → turn **Allow Notifications** off.
      Back in Rowing Pals Settings, expect a first row **Notifications are off**; tapping it opens
      the iPhone Settings page. Turn Allow Notifications back on; the row disappears.

### 4. Who gets told (check in the SQL editor)
Keep this query in a SQL editor tab and **Run** it after each step:
```sql
select n.kind, r.display_name as recipient, a.display_name as actor, n.created_at, n.sent_at
from notifications n
join profiles r on r.id = n.recipient_id
join profiles a on a.id = n.actor_id
order by n.created_at desc
limit 10;
```
Before the paid account, `sent_at` stays empty — nothing can be delivered yet, and nothing is lost.
- [ ] **B** comments on one of **A**'s posts. Expect a new row: `comment`, recipient **A**, actor **B**.
- [ ] **A** replies on that same post. Expect: `reply`, recipient **B**, actor **A** (B commented
      there first). A gets no row for their own comment.
- [ ] **A** turns **Comments and replies** off; **B** comments again. Expect: **no** new row for A.
      Turn it back on.
- [ ] **B** turns **Club activity** on; **A** posts a session. Expect: `club_post`, recipient **B**.
- [ ] **A** posts a test that beats A's previous best for it. Expect: `pb` rows for **A** and for
      **B** (B follows A) — and no `club_post` row for B for that post (the PB alert replaces it).
- [ ] **A** blocks **B**, then B comments on A's post. Expect: **no** row. Unblock afterwards.

## Part 3 — After joining the paid Apple Developer Program

### 5. Enrol
1. Go to **developer.apple.com/programs/enroll** → **Start your enrollment** → sign in with your
   Apple ID → choose **Individual / Sole Proprietor** → follow the steps and pay (£79/yr).
2. Wait for Apple's "Welcome to the Apple Developer Program" email (usually within 1–2 days).
3. **Done 2026-10-04.** The paid team kept the same Team ID (`X734984ZF7`), so signing needed no
   change. Push is switched on by `aps-environment` in `Rowing Pals/Rowing Pals.entitlements`;
   Xcode's automatic signing registered Push Notifications on the app ID on the next build.

### 6. Create the push key
1. **developer.apple.com/account** → **Certificates, IDs & Profiles** → **Keys** → blue **+**.
2. **Key Name:** `Rowing Pals Push`. Tick **Apple Push Notifications service (APNs)** →
   **Configure** → Environment **Sandbox & Production**, Key Restriction **Team Scoped (All
   Topics)** → **Save** → **Continue** → **Register**.
3. Click **Download**. This is the only time Apple lets you download it — keep the file
   (`AuthKey_XXXXXXXXXX.p8`) somewhere safe, never in the project folder.
4. Note the **Key ID** (10 characters, also in the file name). Your **Team ID** is under
   **Membership details** on developer.apple.com/account.

### 7. Give the key to Supabase
In **Terminal**, run these one at a time, replacing `KEYID` and `TEAMID` with yours and the
path with where the `.p8` file is:
```bash
cd "/Users/piero/Documents/Rowing app/Rowing Pals"
```
```bash
supabase secrets set APNS_KEY_ID=KEYID APNS_TEAM_ID=TEAMID
```
```bash
supabase secrets set APNS_PRIVATE_KEY="$(cat ~/Downloads/AuthKey_KEYID.p8)"
```
Expect: `Finished supabase secrets set.` each time.

### 8. Real alerts (A on the phone, B on a simulator)
Rebuild onto the phone with **Cmd + R** after step 5.
- [ ] Lock the phone. **B** comments on A's post. Expect within seconds: a lock-screen alert
      **"B's name — Commented on your *label*: “…”"** with a sound.
- [ ] Tap the alert. Expect: the app opens straight onto that post.
- [ ] With the app open on the **Feed**, B comments again. Expect: a banner at the top; tapping
      it opens the post on top of the feed; the back button returns to the feed.
- [ ] Open **Settings**, and have B comment again; tap the banner. Expect: the post opens over
      Settings; back returns to Settings.
- [ ] A posts a PB. Expect on A's phone: **"New personal best — Your 2k is now 7:04.1."** (with
      A's real test and time).
- [ ] **Log out** on A's phone; B comments. Expect: **no** alert on A's phone. Log back in.

## Cleanup
In the SQL editor, run:
```sql
delete from comments where body like 'TEST%';
```
Their alerts go with them. Unblock B if still blocked.

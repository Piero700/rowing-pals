# Seconds tests and profile pictures — setup and test checklist

Decisions 28 and 29 in `docs/design/v2-decisions.md`. Run against the **staging** Supabase
project (Rowing-Pals-Dev). Tick each box; anything that doesn't match "Expect" is a bug — note
the step.

## Cast

- **A** — you, on your phone: the owner of UEA Boat Club.
- **B** — your test account on the simulator, a member of UEA Boat Club.

## Part 1 — One-time setup

### 1. Run the migration
1. Open **supabase.com**, sign in, and open the **Rowing-Pals-Dev** project.
2. In the left sidebar click **SQL Editor**, then **+ New query** (top left of the editor).
3. In Finder, open `docs/migrations/2026-10-05-seconds-tests-and-avatars.sql` (in the project
   folder) with TextEdit, press **Cmd + A**, then **Cmd + C**.
4. Click in the empty query box in Supabase, press **Cmd + V**, then click **Run** (bottom right).
5. Expect: **Success. No rows returned.**
6. Check the bucket: in the left sidebar click **Storage**. Expect a bucket called **avatars**
   (with a lock — it's private).

## Part 2 — Seconds tests (A)

- [ ] **Rankings** → **Test results** → **＋ Add test**. Expect three choices:
      **Distance · Minutes · Seconds**.
- [ ] Tap **Seconds**, type **30**. Expect "Shown as 30s. Results rank by furthest distance."
      and **Add 30s test**. Tap it. Expect a **30s** tile.
- [ ] **＋ Add test** → **Seconds** → **240**. Expect red **"That's already a standard test."**
      (240 seconds is the 4min test).
- [ ] **Seconds** → **120**. Expect "Shown as **2min**" (a whole number of minutes is named in
      minutes).
- [ ] **Seconds** → **5**. Expect red "A timed test must be from 10 seconds to 120 minutes."
- [ ] Post to it (needs the camera photos): Log a piece whose time is **0:30.0**, Session type
      **30s test**, Post. Then set the time to **0:32.0** before posting another: expect
      **"A 30s test must be 30s long."**

## Part 3 — Profile pictures

### On your phone (A)
- [ ] **Profile**. Expect a small blue **camera badge** on the bottom-right of your picture.
- [ ] Tap your picture. Expect **Profile picture** with **Take photo** and **Choose from library**.
- [ ] **Take photo** → iOS asks for the camera if it hasn't already → take a selfie → move and
      scale it in the square → **Use Photo**. Expect a spinner on the picture, then your photo
      in the circle.
- [ ] Tap it again → **Choose from library** → pick a photo → **Choose**. Expect it replaces
      the first.
- [ ] Go to **Feed**, **Rankings**, **Your crew**: expect your photo in place of your initials
      wherever you appear.
- [ ] Tap your picture → **Remove photo**. Expect your initials back, everywhere.
- [ ] Set a photo again for the next part.

### On the simulator (B)
- [ ] Find A in the feed, the rankings, or Your crew's member list. Expect A's photo. If B still
      shows initials, wait a minute, then open a screen where A appears (e.g. Profile → Your
      club) — a new picture reaches other phones within about a minute.
- [ ] Open A's profile (tap their name). Expect their photo, and **no** camera badge (only your
      own picture can be changed).

### Private accounts
- [ ] **A**: Settings → Profile visibility → **Private**. **B** is not an approved follower of A
      (unfollow first if needed). **B**: anywhere A appears, expect **initials**, not the photo.
      Set A back to Public afterwards.

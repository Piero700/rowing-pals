# Helper text, sign-in, clubs and the optional selfie — phone tests (decision 98)

Branch `t43-clubs-guidance-selfie` (from `main`). Built 2026-11-05.

**Order:** (1) run the SQL below on **Staging**, (2) install the build, (3) go through the tests,
(4) only then do the same SQL on **Production**.

---

## SQL: what to run, click by click

You run these yourself in the Supabase SQL editor. Nothing here was run for you.

### How to open the SQL editor

1. Go to <https://supabase.com/dashboard> and sign in.
2. Click the project: **Staging** first (do Production only after the phone tests pass).
3. In the left sidebar click **SQL Editor** (the `>_` icon).
4. Click **+ New query** (top left of the editor). A blank editor opens.

### Step A (optional, but needed if you want real owners to pick names): delete every club

> ⚠️ **This deletes every club and cannot be undone.** For every club it removes:
> - the club itself (name, description, place, join rule, focus, week start);
> - **every membership**: every rower and coach is taken out of their club, roles go back to
>   member, and **nobody is a coach any more**;
> - join requests, invitations and invite codes;
> - **squads** and who's in them;
> - club tests (the custom test tiles);
> - **set workouts**, their attendance, **coach notepads and notepad scores**;
> - **practices, availability answers, registers, events, terms**;
> - **saved boats, water sessions and their crews**;
> - **announcements, challenges, erg events**;
> - club notifications (join requests, workouts, practices, announcements…);
> - verification applications.
>
> **It keeps** every account, profile, post, photo, comment, reaction, follow, PB and test result.
> A post linked to a coach's workout or an erg event just loses the link. Nobody is sent back to
> onboarding; everyone is "No club yet" and can find, join or create a club from Profile → Your crew.
>
> Coach-only accounts (who don't row) are left with no club, so they see the coach app with no
> club until they join or create one.

1. **Back up first (Production especially):** left sidebar → **Database** → **Backups** → check
   there's a recent backup (Supabase takes them daily on paid plans). On the free plan there's no
   restore, so be sure.
2. In Finder open the repository and the file `docs/migrations/2026-11-05-delete-all-clubs.sql`.
   Open it in TextEdit (right-click → Open With → TextEdit), press **⌘A** then **⌘C**.
3. Back in the SQL editor, click in the blank query and press **⌘V**.
4. Click **Run** (bottom right, or **⌘↩**). If Supabase warns that the query is destructive, click
   **Run this query** to confirm.
5. At the bottom you'll see one row: `clubs_left` **0** and `rowers_still_in_a_club` **0**. If
   either isn't 0, stop and send me a screenshot.

### Step B (required): open clubs, unique names, renaming, verification

1. Click **+ New query** again.
2. Open `docs/migrations/2026-11-05-clubs-open-and-verified.sql` in TextEdit, **⌘A**, **⌘C**.
3. Paste into the editor (**⌘V**) and click **Run**.
4. Expect **"Success. No rows returned"**. If you get
   `could not create unique index "clubs_name_unique"`, two clubs have the same name apart from
   spacing. Run this to see them and screenshot the result to me:
   ```sql
   select id, name from clubs order by lower(regexp_replace(btrim(name), '\s+', ' ', 'g'));
   ```
5. It's safe to run again if anything went wrong part-way.

### Approving (or declining) a club's verification

When an owner applies, the application waits in `club_verification_requests`. To check them:

1. SQL Editor → **+ New query**, paste and **Run**:
   ```sql
   select r.club_id, c.name as club, r.message, r.created_at,
          p.display_name as asked_by, p.username
   from club_verification_requests r
   join clubs c on c.id = r.club_id
   left join profiles p on p.id = r.requested_by
   where r.status = 'pending'
   order by r.created_at;
   ```
2. You'll see one row per waiting club. Check the club is real and that `asked_by` runs it (their
   note may give a website or British Rowing code).
3. **Send me a screenshot of that result** and I'll give you the exact line with the id filled in.
   Or do it yourself: click the `club_id` cell, copy it (**⌘C**), and run **one** of these in a new
   query, pasting the id between the quotes:
   - Approve (the tag appears for everyone straight away):
     ```sql
     select approve_club_verification('PASTE-CLUB-ID-HERE');
     ```
   - Decline (the owner sees "Not approved" and can apply again):
     ```sql
     select decline_club_verification('PASTE-CLUB-ID-HERE');
     ```
   - Take the tag away later:
     ```sql
     select remove_club_verification('PASTE-CLUB-ID-HERE');
     ```
4. Expect one row with an empty value: that means it worked. "No club has that id" means the id
   was pasted wrongly.

Nobody signed in to the app can call these three. Only you can, in the SQL editor.

---

## Phone tests

Use two accounts, **A** and **B**, on Staging.

### 1. Helper text (7 days, and the switch)

- [ ] On a fresh install, explanations show, e.g. Settings, under Privacy: "Your club's coaches can
      always see your training…".
- [ ] Settings → **Help** → **Helper text** is on. Turn it **off**: the Privacy note goes, with no gap
      where it was. Open Your crew, Create a club, Calendar, Log's Review: their notes are gone too.
- [ ] Empty states keep their fact: e.g. Coaching → Workouts with none reads "No workouts yet." without
      "Tap + to set one…".
- [ ] Errors still show with helper text off (e.g. type a club name that's taken, see 3).
- [ ] Turn it back **on**: everything returns.
- [ ] The 7-day count (it can't be rushed without changing the date): iPhone Settings → General →
      Date & Time → turn off Set Automatically, then open the app on 7 different dates (close and reopen
      it after each change). On the 7th date the notes are gone and the switch reads off. Put the date
      back to automatic. Choosing the switch by hand at any point overrides the count from then on.

### 2. Sign in

- [ ] Sign out. **Forgot password?** is on the left under the password, not the right.
- [ ] **Sign in with Apple** and **Continue with Google** are at the bottom of the screen, with "or" above
      and the terms line under them; the email form and "New here? Create an account" are at the top.
- [ ] Create your account: the same layout.
- [ ] Both buttons still sign in.

### 3. Clubs

- [ ] **A** (in a club, not owner): Profile → Your crew → bottom: **Create your own club**. Create
      "TEST Tyne RC". A becomes its **owner** and is now in it (Your crew shows "You're the owner").
- [ ] **B**: Your crew → Create… (or Find a club → **Create a club**) and type `test tyne rc` or
      `  TEST   Tyne RC  `: under the name, in red, "There's already a club called … choose another
      name", and **Create club** greys out.
- [ ] New sign-up: onboarding's Find your club has **Create a club** under "Have an invite code?";
      creating one goes straight on to About you, and the new account owns the club.
- [ ] **A** (owner): Settings → **Your club** → **Club name** → change it, **Save name**. The new name
      shows in Your crew, Manage club, club search and on A's profile. Try another club's name: red
      error, Save disabled.
- [ ] Non-owners (co-owner, admin, member, coach) don't see Settings → Your club.
- [ ] An owner sees no Create your own club button; Your crew says to hand the club over first.

### 4. Verification

- [ ] **A**: Settings → Your club → **Verification** reads **Apply**. Open it, add a note, tap **Apply for
      verification**: it now reads "Waiting to be checked", and the Settings row reads **Waiting**.
- [ ] Run the approval SQL above for A's club.
- [ ] Reopen the app. The **shield-with-tick** tag shows beside the club name in: club search
      (Find a club), Your crew, Manage club, A's profile, a clubmate's profile, the coach's profile,
      feed cards, Following/Followers lists, follow requests, Invite rowers, Rankings → Volume and a
      test's board (including "your row").
- [ ] Settings → Your club → Verification reads **Verified**.
- [ ] Decline: on another test club, apply, run `decline_club_verification`, reopen: "Not approved"
      with **Apply again**.

### 5. The selfie is optional

- [ ] Rower account: Settings → **Logging** → **Selfie with each session** is on.
- [ ] Log: under the camera, "Front + rear · No time limit" and **Selfie** on; the front inset shows.
- [ ] Turn **Selfie** off: the inset and the flip button go, it reads "Monitor only · No time limit",
      and the front camera isn't on.
- [ ] Take the monitor photo: Review reads the numbers as usual; **Include on leaderboards** is there
      (not the manual-session note) and Session type offers the tests.
- [ ] Post it. Feed: the card shows the monitor photo with **no** inset. Open it: no selfie box. Profile
      and Rankings → Volume count it.
- [ ] Post one as a 2k test without the selfie: it reaches the 2k board.
- [ ] Settings → Logging → turn it **off**: Log now opens with Selfie off. Turn it on in Log for one
      session: that session takes the selfie; the next opens off again.
- [ ] A session with the selfie still looks as before (inset on the feed, swap on tap).

---

## Everything marked as helper text

Hidden after 7 days, or when turned off. Shown in full while on.

**Settings:** "Only the club's owner sees this. Everything else about the club is in Manage club." ·
"You can still turn it on or off on the Log screen for one session." · "Only coaches see this. Rankings
and streaks still run Monday to Sunday." (an error in the same place still shows) · "Your club's coaches
can always see your training, age and bodyweight." · Club name: "Everyone sees the new name straight
away…" · Verification: "We check that the club is real and that you run it…"

**Log / Review:** Corner picker: "Choose which corner the front camera preview sits in." · "Manual
sessions count toward your own totals and streak, but never appear on leaderboards…" · "A photo of the
erg monitor is read and added as a piece…" · "A test is an all-out effort, so AN is chosen…" · "Press and
hold a photo if it's actually a monitor photo." · "Friends: people you follow who follow you back."

**Clubs:** Your crew: "Join an existing crew, start your own, or row independently." · "Coaches who don't
row never appear in Crewmates or on any leaderboard." · "You own this club. To leave it or start another,
hand it over…" · Create/Edit club: "Start your crew. You'll become the club owner…" and the join-rule
note ("Rowers ask to join; admins, co-owners and the owner accept or decline." etc.) · Invite rowers:
"They'll see the invitation under Your crew…"

**Onboarding:** the intro under each step's title ("Your club powers your feed and team rankings…",
"Know your current 2k or 5k?…" etc.) · "Novice means you're in your first season." · "The side you row
on in a pair, four or eight…" · "You can change this later in Edit profile." · "They count for 30 days,
fading…" · "No gender or level needed. You won't have a Log button…" · Username: "It shows as @username
on your profile…" · "You can change it later in Edit profile." · Confirm email: "Can't find it? Check your
junk folder…"

**Calendar:** "You can change an answer until the session starts…" · Coach calendar: "Tap a day to see
it. Weekly practices fill in by themselves…" · "Tap one to see how it's going, change it or delete it…"
· "Tap one to change it or take it down…" · Register: "'Suggested' ticks come from sessions posted
today…"

**Rankings:** "Join one to see how your metres stack up against your crew." · Erg event: "Log it with
the + as usual…" · Add a club test: "Every member of your club will see it under Test results…"

**Profile:** PB history: "Tap the line or slide to explore each result." · Prediction: "Worked out on
your phone from your erg sessions in the last 30 days." · "Every coloured square is a day you posted a
workout." · All PBs: "Your recorded bests. Select a test to explore its history."

**Coaching:** Piece editor: "Leave the split empty and each rower gets their own target…" · Squads:
"Rowers can be in more than one squad…" · Rowers: "Predictions and flags come from the Pace Engine." ·
New session sheet: "Practices, races and other events are added from the Calendar…" · Crewing: "Stroke
side's oars are above the boat, bow side's below." · Saved boats: "Crews you put out again and again…"
· Notepad: "Only your club's coaches see this page…" · Erg order: "Drag rowers to match the ergs…" ·
Effort chart: "Tap the chart to see each week."

**Empty states (the fact stays, only the hint goes):** "No workouts yet." (+ "Tap + to set one…") · "No
water sessions coming up." (+ "Tap + and choose Water session…") · "No saved boats yet." (+ "Save one
here…" / "Make a new one…", two places) · "No sessions set for you this week yet." (+ "When your coaches
add practices…") · "No comments yet." (+ "Say something…") · "No boats yet." (+ "Your coach crews the
boats…") · "No practices this week yet." (+ "Add them from the Calendar.") · "Your club has no squads
yet." (+ "Coaches, the owner and co-owners make them in Squads.") · "N of M answered." (+ "Your coaches
plan the week from your answers…") · "Showing N of M." (+ "Sessions are linked when a rower posts…")

**Deliberately not marked:** errors; alert and confirmation messages; row subtitles in lists and
Settings; the coach privacy notice when joining a club (it's consent); the Delete account warning;
"At least 8 characters."; the Notepad's posted-score legend; Log's Help sheet (opened on purpose).

---

## Built beyond what was asked — please check

- **Create a club in onboarding** (with a small host so it works before the app shell exists), because
  after deleting every club a new rower would otherwise have no way to create one.
- **"Create your own club" for people already in a club.** The button only existed for people without
  a club, which is likely why "nobody can" create one.
- Names are unique ignoring **extra spaces** too, not just capitals, and are stored tidied.
- A **live "name taken" check** while typing, on create, edit and rename.
- **Decline** and **remove** verification functions, an optional note with the application, and
  "Not approved / Apply again".
- The verified tag also on **feed cards, people lists, follow requests, Invite rowers and the
  leaderboards** ("everywhere the name appears").
- A **Help** item on the Log screen explaining "No selfie".
- With the selfie off the **front camera doesn't run at all** (not just hidden), and the flip button hides.
- **`GuidedText`** for empty states, so the fact stays while the hint hides.
- Co-owners can also rename through `rename_club` (they could already edit the name in Edit club);
  only owners see Settings → Your club.

## Not checked

- On a real phone: the camera with the selfie off (the simulator has no camera), and Apple/Google sign-in.
- Anything against the new SQL: Dev and Staging don't have the migrations yet, so the live name check,
  renaming, applying and the tag itself were checked only in code, unit tests and renders with sample data.
- The 7-day switch over real days (unit-tested; the day count was seen being stored on the simulator).

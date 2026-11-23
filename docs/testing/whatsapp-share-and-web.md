# WhatsApp share picture and the rower web page — phone checklist (decision 110)

Written 2026-11-19. Branch `t48-whatsapp-web`. Two parts: the iPhone (coach version) makes the picture, and a
browser or Android phone uses the web page. Do the **web launch steps for staging** in
`docs/production/web-launch.md` (sections 1 to 3) first, or part B won't work. Tick each box as you go.

**Things in here that weren't in the canvas or the brief (check them):**
- The week card's rows, wording and footer (the design's text, laid out by Claude).
- Rest shows as "5:00 rest" on the card (a piece's line ends with it; a week row's erg line reads "rate · 5:00 rest").
- The workout card's line under the title: who it's for (its squads, or the club; a workout for chosen rowers shows the
  club, as no rower's name goes on the picture), the day and time, then the zone if one was chosen (AN on a test day).
- On the web: the 6-digit email code screen, the "Waiting for the club to approve you" screen and the
  "Coach tools are in the iPhone app for now" note.

## Before you start
- [ ] On your iPhone, install the build from this branch from Xcode (Staging scheme), signed in as a coach whose club has
      at least one practice or workout this week and next week. If it has none, add one in Calendar first.
- [ ] Have a real WhatsApp group (you plus one other person is enough) open on the iPhone.
- [ ] Staging only: Supabase → **Authentication** → **Providers** → **Email** → look at **Confirm email**. (On, checked 2026-11-23.)
      CLAUDE.md says it's off on staging, but staging has been sending a 6-digit code by email. Write down what it shows
      (on or off). It decides whether step B2 shows a code screen.

## A. On the iPhone: Share week
1. Open the app and switch to the coach version (the coach tab bar: Rowers, Workouts, Boats, Calendar, +).
2. Tap **Calendar**.
3. At the top right of the Calendar screen there are two round icons. Tap the share icon (Share week: an arrow pointing
   up out of a tray, the left one of the two). A sheet opens.
   - [ ] The sheet shows **Which week**, **Who for** and a picture preview.
4. Under **Which week** tap **This week**.
   - [ ] The preview's title says **This week** and the dates under it match this week.
   - [ ] Every practice, race and land workout for the week is listed once, in time order, with the day and time in blue.
   - [ ] Cancelled practices are not on it.
   - [ ] No rower names, crews or seats appear anywhere.
5. Tap **Next week**.
   - [ ] The title says **Next week** and the dates move on by seven days.
   - [ ] The week starts on the day set in your club's **Week starts on** setting.
6. Under **Who for** tap **Whole club**, then pick one squad.
   - [ ] The squad name appears under the title.
   - [ ] The squad version shows that squad's items and the whole-club items, and nothing for other squads.
7. Pick a week with nothing in it, if you have one.
   - [ ] It says **Nothing planned yet** and can still be shared.
8. Tap **Share**. The iPhone Share sheet opens. Scroll the app row and tap **WhatsApp**, choose your group and send.
9. Open the WhatsApp group on the iPhone.
   - [ ] The picture arrived.
   - [ ] The link **https://rowingpals.com/go** arrived as the picture's caption (under it, not as a separate message).
         If it arrived separately or not at all, write down which.
   - [ ] Zoom the picture: every line is readable at normal size on the phone.
   - [ ] The footer reads "No iPhone? Say if you can make it at rowingpals.com/go" and the Rowing Pals name is under it.
   - [ ] Turn the iPhone to light mode (Settings → Display & Brightness → Light) and share again: the picture is still dark.

## A2. On the iPhone: Share workout
1. In the coach version tap **Workouts**.
2. Tap a workout that has pieces (for example 3 × 2k with a rate and a rest).
3. On the workout page tap the share icon at the top right (Share workout: an arrow pointing up out of a tray, left of
   **Edit**). The same sheet opens.
   - [ ] It shows one day: the day, date and start time, the workout title, and each piece with its targets (split, rate, rest).
   - [ ] There is no **Which week** or **Who for** choice.
   - [ ] The line under the title starts with who the workout is for: the squad name(s), or your club's name.
         For example "Novice men · Wed 25 Nov · 06:30 · UT2".
   - [ ] The zone (UT2, UT1, AT, TR or AN) ends that line if the workout has one; a test day shows AN; with no zone
         chosen there is none.
   - [ ] Rest shows as "5:00 rest", at the end of each piece's line.
4. Tap **Share**, pick **WhatsApp**, your group, and send.
   - [ ] Same checks as A9: the picture arrives, the link is its caption, the picture is readable.

## B. On an Android phone, or a browser on your laptop
Use https://rowingpals.com/go/ — since 2026-11-23 rowingpals.com is the test site, on staging data (see the note at the
top of `docs/production/web-launch.md`).
On a laptop you can narrow the window to phone width to see the phone layout.

### B1. Sign-in screen
1. Open the staging web address followed by `/go/`.
   - [ ] You see a sign-in screen with email or username, password, **Continue with Google**, **Create account** and **Forgot password**.
   - [ ] There is no Sign in with Apple.
   - [ ] The look matches the app: dark colours, grouped rows, numbers in neat columns. Switch the device to light mode: it follows.

### B2. Create account
1. Tap **Create account**.
2. Type a name, a new email address you can read, a password.
3. Tap the date of birth row and choose a date that makes you **12**.
   - [ ] It says "Rowing Pals is for people 13 and over." and won't let you continue.
4. Change it to a date that makes you over 13. Tick the Terms and Privacy agreement (the two links open rowingpals.com/terms and /privacy).
5. Tap **Create account**.
   - [ ] If Confirm email was **on** (see Before you start): a 6-digit code screen appears; get the code from your email, type it and continue.
   - [ ] If it was **off**: you go straight on.

### B3. Username
1. On **Choose a username**, type one that is taken (try `piero`).
   - [ ] It says "That username is taken. Try another."
2. Type a free one.
   - [ ] It says "@yourname is free." (with the name you typed), and Save works.

### B4. Join your club
1. On **Join your club** type your club's invite code and continue.
   - [ ] It shows your club's name and you join.
2. (Optional) sign up a second test account and use the search instead of the code, with a club that needs approval.
   - [ ] It shows "Waiting for the club to approve you" with **Cancel request**. Approve it on the iPhone (coach version → the club's requests) and refresh the web page: it moves on.

### B5. Your week
1. You land on **Your week** with **This week** and **Next week**.
   - [ ] Each day lists the practices and races you can see, with time, title and place.
   - [ ] You don't see other rowers' names, answers or reasons.
2. On a practice tap **Available**.
   - [ ] It shows as chosen. Reload the page: it is still chosen.
3. On another practice tap **Can't**.
   - [ ] A box asks for an optional reason and says only coaches see it. Type "Exams" and save.
   - [ ] It shows as Can't. Reload: still Can't.
4. On a race or event tap **Yes** on one and **No** with a reason on another ("**Can you race?**").
   - [ ] Both stick after a reload.
5. Make a practice on the iPhone (coach version → Calendar → +) that starts **within the next 30 minutes** (or has already started and not ended).
   - [ ] On the web page that practice shows **Check in**. Tap it.
   - [ ] It now says "Checked in" with the time.
6. Look at a practice that starts in more than 30 minutes, and one that has ended.
   - [ ] Neither shows **Check in**.

### B6. Account
1. Tap **Account**.
   - [ ] It shows your username and club.
   - [ ] **Leave club** and **Delete account** are red rows. **Sign out** is not.
2. Tap **Sign out**.
   - [ ] You're back at the sign-in screen. Sign in again with your email and password, then with your username and password: both work.
3. Sign in as a **coach** account (a coach-only one, if you have it).
   - [ ] It says "Coach tools are in the iPhone app for now."
4. Do not delete your real account. Delete the test account at the end (step D).

## C. The coach sees it on the iPhone
1. On the iPhone, coach version, tap **Calendar**, then the Who's available icon at the top right (two people with a
   tick, the right one of the two round icons). Choose **This week** or **Next week** to match the practice, then tap the
   practice you answered **Available** on.
   - [ ] Your web account is listed as Available.
2. In Who's available, tap the practice you answered **Can't** on.
   - [ ] It shows Can't, with the reason "Exams".
3. Go back to **Calendar**, tap the practice you checked in to, and tap **Take register**.
   - [ ] Your web account shows as checked in with the time.
4. In Who's available, scroll to the races coming up and tap the race you answered.
   - [ ] Your Yes and No answers are shown.

## D. Tidy up
- [ ] In the web page sign in as the test account and tap **Account** → **Delete account** → confirm. Check that it signs you out and that signing in again fails.
- [ ] Delete the throwaway account made during development: Supabase → pick the **staging** project →
      **Authentication** (left bar) → **Users** → find the one whose email starts **webtest.** (it was never confirmed) →
      click the three dots at the end of its row → **Delete user** → confirm.

Tell Claude what you ticked and what you wrote down (the Confirm email setting, the caption).

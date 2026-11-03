# Rowing Pals: what the analysis found

Written 3 November 2026. This pulls together the app review of 19 October 2026 (the full interactive
report is at https://claude.ai/artifact/BRMTbUZZnxqyuN4TpyRqdn), the Android and web estimate, and
what we found about clubs, since then.

**How far to trust the numbers.** The review simulates 1,000 invented people going through the app as
it is built. It is a structured thought experiment, not market research. The group sizes and
probabilities are assumptions (for example, about 35% of UK students are on Android). Use it to
compare groups and fixes against each other, not as a forecast of real sign-ups.

---

## 1. The verdict

**A great product for a whole club. Close to useless for one rower on their own.**

- Where a rower's whole club is on it, **91%** of those who got through sign-up were still using it at
  12 weeks.
- Where only some teammates were on it, **43%** stayed. Where the rower was the only one at their
  club, **8%**. With no club, **5%**.

So adoption, not features, decides whether the app lives. Four things get in the way:

1. **About 4 in 10 interested people can't install it.** It is iPhone only (see section 6 for how
   the iOS minimum has changed since).
2. **It doubles the work for serious rowers.** Most already send every piece to the Concept2 Logbook
   through ErgData. Here they photograph the monitor and their face as well.
3. **It logs only the erg, in a sport that lives on the water.** From March the feed goes quiet just
   as the club gets busy, while coaches are crewing water sessions inside the same app.
4. **Alone, it's empty.** With no clubmates there's no feed, your ranking is a list of one, and
   there are no challenges.

## 2. What it already does well

- **Proof built in.** A monitor photo plus a live selfie makes every ranked score believable.
- **Made for rowing.** Seats, sides, coxes, rigging, boats drawn on their side with your seat in blue.
- **One app for the club.** Today's workout, your boat, availability, registers and results in one
  place, instead of a spreadsheet, a WhatsApp group and a whiteboard.
- **Rewards that feel earned.** The PB glow, PB history, 2k predictions with a ± and Season Wrapped.
- **Careful craft.** Consistent design values, aligned numbers, swipe back everywhere, UK English.
- **Privacy taken seriously.** Private accounts, blocks, reports, and visibility enforced by the
  database, not just the app.

## 3. The simulated 1,000

| Outcome | People |
|---|---:|
| Couldn't install | 389 |
| Left during sign-up | 64 |
| Stopped in the first month | 303 |
| Stopped between weeks 4 and 12 | 44 |
| **Still using it at 12 weeks** | **200** |

The net promoter score (share who'd recommend minus share who wouldn't) is **−46**.

**By group** (share of each group that could install, and that stayed to 12 weeks):

| Group | People | Could install | At 12 weeks |
|---|---:|---:|---:|
| UK university novice | 201 | 64% | 26% |
| UK university senior | 225 | 65% | 27% |
| UK university coach or captain | 29 | 62% | 41% |
| UK junior (13 to 18) | 88 | 57% | 22% |
| UK club senior | 75 | 57% | 23% |
| Masters rower (35+) | 94 | 51% | 13% |
| Cox | 26 | 54% | 23% |
| US college or high-school rower | 86 | 85% | 13% |
| Indoor or fitness erg user | 96 | 46% | 2% |
| Club or school coach (not university) | 30 | 43% | 17% |
| International club rower | 50 | 64% | 6% |

**Why people left** (most common reasons): Android phone (331), logging twice with ErgData (142),
on the water most of the season (117), iPhone not on iOS 26.5 (58), six steps before seeing anything
(37), empty Feed and Rankings without their club (28), PM3/PM4 monitor not read (20), gender only male
or female (17), UK terms that don't fit their rowing (16).

**What people liked most:** PB history and the PB glow (309), seeing the crew's sessions and
reacting (173), the dark glassy look (144), verified club leaderboards (139), 2k predictions with a ±
(124), today's workout, boat and calendar in one app (115).

## 4. The main problems, in order of weight

**Blocks growth**
- **A third of a club can't install it.** Coach tools need everyone: a register or crew sheet missing
  a third of the squad adds to the spreadsheet instead of replacing it.
- **Logging twice** for anyone who uses ErgData. Fix: import from the Concept2 Logbook (it has an
  official API), count Logbook results as verified, and keep the photo and selfie as the social way
  to post.
- **Erg only, in a water sport.** Fix: a simple water post. When a sent water session ends, ask "Did
  you row?" with the boat, crew and plan filled in, for coxes too. (Water logging was removed on
  purpose in decision 54, so this needs your say-so.)
- **Safeguarding for juniors.** No age check; under-18s post selfies, and adult coaches see date of
  birth and bodyweight. A school or junior club will ask about this first. Fix: date of birth at
  sign-up; under-18s private by default, selfie optional, no bodyweight without a guardian's OK; a
  safeguarding note clubs can show.
- **Coaches: it only works if every rower is on it.** Fix: let coaches add rowers without accounts
  (name, side, level) to squads, registers and boats, and add a web link for availability.

**Hurts daily use**
- **Nothing for a rower on their own.** Rankings cover only your club or people you follow. Fix:
  opt-in open boards, with optional age and lightweight categories.
- **Two products need two kinds of adoption.** Lead with the coach: a coach who sets workouts and
  sends boats gives every rower a daily reason to open the app, and the feed follows.
- **Review screen: twelve controls for one piece.** Show total, pieces, caption and Post; put the
  rest under "More options".
- **A post can be lost.** There's no saved draft or upload queue. Fix: keep the draft on the phone
  and retry in the background.
- **Capture is tuned to one screen** (the PM5 end-of-piece table). PM3/PM4 and other ergs are typed
  and never ranked.
- **Text ignores the iPhone's text size setting**, which also shows up in App Store accessibility
  reviews.
- **Names that mean two things:** "Your crew" is both the Feed's title and the club page; "Everyone"
  means clubmates and followers; "Land session" for an erg.
- **Too much above the posts** on a busy Feed. **No export at all** (UK GDPR and coaches both need
  one). **Coaches always see bodyweight**, even on private accounts (decision 34). **One club per
  rower** (a problem at Oxford and Cambridge, and for juniors). **No laptop version** for coaches.

**Polish:** jargon for novices (UT2, AT, TR, AN, ±), glass on everything flattens the hierarchy,
every post leads with a grey monitor photo, light-mode contrast, gender options ("Prefer not to
say"), no alerts for challenges, Wrapped needs the coach to set terms, no business model.

## 5. What each fix is worth (same 1,000 people, one change at a time)

| Change | Still using at 12 weeks | Change |
|---|---:|---:|
| Today | 200 | |
| An Android app | 311 | +111 |
| Leaderboards beyond your own club | 258 | +58 |
| Import from the Concept2 Logbook | 233 | +33 |
| Log water outings (coxes included) | 231 | +31 |
| Run on iOS 17 and up, not only 26.5 | 226 | +26 |
| Make the selfie optional | 213 | +13 |
| Export for rowers and coaches | 205 | +5 |
| Text that follows iPhone text size | 202 | +2 |

Together, Android, Logbook import, water logging and open boards reach **595**. Every fix in the
report together reach **692**, and the net promoter score goes from −46 to **+32**. The fixes add
up because each removes a different group's reason to leave.

**Suggested order**
1. **Before testers form a first impression (days):** fix the double-meaning names; keep every post
   on the phone until it's sent; show the right PM5 screen before the first photo; "Prefer not to
   say" for gender; bodyweight shared only if the rower agrees; date of birth and junior defaults; a
   shorter Review screen; text that follows the iPhone's size setting.
2. **Before a public launch (this decides adoption):** coach tools that work for the whole squad;
   Concept2 Logbook import; water outings and something for coxes; open opt-in leaderboards;
   optional selfie; export; more than one club per rower.
3. **The long game:** Android or a full web app; a coach web dashboard; one outing instead of a
   practice plus a water session; a paid club plan to cover photo storage and push costs.

## 6. What has changed since the review

- **iOS minimum lowered from 26.5 to 26.0** (TestFlight build 2). A test build compiled with no
  errors, so nothing in the app needs newer than 26.0. This shrinks the "iPhone not on 26.5" group
  but doesn't reach phones that can't run iOS 26 (iPhone 8, X). It hasn't been run on a real 26.0
  device. Full detail: `docs/testflight-and-ios-support-findings.txt`.
- **Friends (decision 95):** a follower sees your posts only if you follow them back. Merged
  without a phone test; the checklist is `docs/testing/friends.md`, and the staging database change
  has been run.
- **"Split", not "pace" (decision 94)** in what rowers read, and a rules audit tidied tabular
  figures and spacing values.
- **Monitor reading:** two fixes (a damaged summary row, and a PM3 interval distance read as 0), with
  a test that reads all 16 sample photos. This doesn't add support for other monitors or ergs.
- **TestFlight is live** (RP Beta, from the staging configuration, never production).

Not done from the review: Logbook import, water logging, open boards, Android or web, the
safeguarding changes, export, text size, the Review screen, draft saving, several clubs per rower.

## 7. Android and web: how big a job

- **A web app (works on any phone's browser):** about **4 to 8 weeks**. It would cover the
  coach-critical parts first (availability, calendar, boats, results) so rowers on Android can take
  part and coaches get a laptop view.
- **A native Android app:** about **3 to 5 months**, because the app is SwiftUI throughout.
- **Recommended order:** web first, then Android if demand justifies it. Not decided yet.

## 8. Clubs: making sure real members use a club

**The gap.** About 300 UK clubs were pre-loaded (`docs/migrations/2026-09-30-club-directory.sql`).
Every one is open to join and has no owner, so anyone who signs up can join a real club. Joining
shows them clubmates' Club and Everyone posts, puts them on the club's rankings, and gives any coach
a view of members' training. UEA Boat Club is fine because you own it; you can also set **Manage club
→ Who can join** to Approval.

**The agreed plan (option 1, not built yet).**
- Unclaimed clubs switch to **Approval**. A rower taps **Claim this club**, which saves a claim with a
  short code (for example `RP-7K3Q`) and opens Mail with a message to the club-claims address.
- You approve or decline in the app (**Settings → Club claims**, your account flagged as admin).
  Approving makes them the club's owner, and it can be reversed.
- Join requests to an unclaimed club wait for its owner.
- **How you tell it's genuine:** match the code, check the email comes from an address the club itself
  publishes (club domain, university society, British Rowing listing), and if unsure, write to the
  club's published contact yourself and approve only if they confirm.

**Domain and email.** You own **rowingpals.com** (GoDaddy); its mail runs on Microsoft 365 as
`noreply@rowingpals.com`, and you're adding `clubs@` and `support@` aliases. The website is a blank
GoDaddy page; the finished site in `marketing/website` still needs hosting. **rowingpals.app is not
owned**: Settings → Contact us uses `support@rowingpals.app`, which bounces (you saw this), so that
and every other `.app` mention must change to `.com`. Apple needs a working contact, support page
and privacy policy before external TestFlight or the App Store.

## 9. Decisions waiting for you

1. Web app first, then Android, or something else? (section 7)
2. Bring back a simple water post? (decision 54 removed it; section 4)
3. Which "before testers" fixes to do first? (section 5)
4. Confirm the `clubs@` and `support@` aliases work, then I build club claims and switch to `.com`.
5. A production Supabase project, which the App Store build needs. The release settings still point
   at a placeholder.

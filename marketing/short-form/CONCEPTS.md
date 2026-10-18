# Rowing Pals: short-form video concepts

October 2026. For TikTok, Instagram Reels and YouTube Shorts (9:16).

**Ground rules followed throughout**
- Every feature shown or named is built and merged on `main` (checked against
  `docs/design/v2-build-plan.md`, `coaching-build-plan.md` and the Swift code). Coaching
  Phase 2 (set workouts) and Phase 3 (attendance) are **not** built, so no concept shows them.
- The app is **not on the App Store yet**. Every CTA is "follow for launch" / "coming soon to
  iPhone" until it is. Swap in a download CTA only on launch day.
- All people, clubs and numbers are fictional: **Wexmoor University Boat Club (Wexmoor UBC)**,
  rowers Rory Ellison, Kit Mallory, Sam Adeyemi, Josh Penrose and Theo Lindqvist. Nothing comes from
  the app's sample data or from any real user.
- No testimonials, no download counts, no "X rowers use it" claims, no "viral" claims.

---

## 1. What a rower actually gets (from the docs and code)

| Reason to care | The feature behind it (built) |
|---|---|
| **Proof.** Your score is a photo of the monitor, not a claim in the group chat. | A post is two simultaneous photos: rear camera on the erg monitor, front camera on you. |
| **No typing.** | On-device OCR reads distance, time and split off the monitor photo; you confirm the stroke rate before posting. |
| **Beat your mates, not the world.** | Weekly / monthly / yearly **volume** boards and **test** boards, scoped to *My club* or *Following*, opening on your own group (gender + novice/senior). "3,501m to move into #1" is the app's real wording style. |
| **Watch yourself get faster.** | PB history per test: a progression line, "49.7 faster", every PB dated; "Best in your group" card on Test results; 2k/5k predictions from the Pace Engine. |
| **Your club in one feed.** | Following / Club feed, emoji reactions, comments, a glow on new-PB posts, streak 🔥 on avatars. |
| **Club life.** | Clubs with roles and join rules, club-specific tests with their own boards, coaches who can see their squad's training (read-only). |

## 2. Research: verified vs hypothesis

**Verified (sources at the end)**
- TikTok's own explainer: the For You feed weighs user interactions (likes, shares, comments,
  watching to the end) far above weak signals. **Follower count and past hits are not direct
  factors**, so a new account's first post can reach non-followers.
- Instagram's head (Adam Mosseri, Jan 2025, as reported by several outlets): the top signals are
  **watch time, likes per reach and sends per reach**. Sends matter most for reaching
  *non-followers*.
- Competitor set: **Concept2 ErgData + Online Logbook** (free; challenges; syncs to Strava/Garmin),
  **ErgZone** (multi-brand erg app: pacing, challenges, online racing), **CrewLAB** (team platform,
  pulls erg workouts from the Logbook). Others listed by r/Rowing's wiki: Asensei, Regatta, EXR,
  Krew, Kinomap (racing / virtual worlds).

**Hypotheses to test (not proven)**
- Inside-joke rowing humour (2k dread, the group chat, erg face, Sunday-night metres) gets
  **sent** to teammates more than a feature demo would. Shares should beat likes.
- "Your club, not the world" is a gap. The competitors above lean on worldwide rankings,
  racing and pacing. A small, *known* leaderboard (your clubmates) is more motivating for
  university rowers. This is untested and comes from the product's own positioning.
- A ~20 s video with the payoff in the last third gets better completion than a 30–45 s
  explainer.
- Rowing-specific erg trends on TikTok couldn't be verified by search (results lag the apps).
  **Check #erg, #2ktest and #rowing in each app before posting** and borrow a current sound or
  format, not one named here.

Sources: [TikTok newsroom: How TikTok recommends videos](https://newsroom.tiktok.com/en-us/how-tiktok-recommends-videos-for-you/),
[dataslayer: Instagram algorithm 2025](https://www.dataslayer.ai/blog/instagram-algorithm-2025-complete-guide-for-marketers),
[Stack Influence: Reels algorithm](https://stackinfluence.com/how-does-the-algorithm-for-reels-work-in-2025/),
[CrewLAB: Concept2 LogBook](https://crewlabteam.notion.site/Concept2-LogBook-7255e11eeef74c43a8408dabe7c10b29),
[r/Rowing wiki: erg apps](https://pol1.lr.ggtyler.dev/r/Rowing/wiki/index/erg_apps),
[insideindoor.com](https://insideindoor.com/?p=13228).

---

## 3. Ten concepts

Each concept lists: audience · emotional trigger · hook (first 1–2 s) · script · shots ·
on-screen text · sound · CTA · why. **★ = produced as a finished video.**

### ★ 1. "Receipts" (pics or it didn't happen)
- **Audience:** university and club rowers, 18–24, who live in a squad group chat.
- **Trigger:** recognition and teasing. Everyone has a mate whose 2k is "6:27, trust me".
- **Hooks:** a) `pov: your mate says he pulled a 6:27 2k` · b) `"trust me, it was a 6:27" 🙄`
  · c) `2k score, or it didn't happen?`
- **Script (22.5 s):** hook → fictional group chat: Kit claims 6:27.6, "pics or it didn't
  happen", typing… "phone died 🫠" (rimshot) → "next session, he logs it on Rowing Pals" → Log
  screen: monitor + face, shutter, flash → "the numbers get read off the photo" (Review screen,
  fields highlighted) → "he just confirms the stroke rate" (tap Confirm) → "receipts. posted to
  the club 🧾" (feed card with new-PB glow, reactions) → end card.
- **Shots:** all rendered: chat mock-up, app screens, an illustrated monitor.
- **CTA:** "Coming soon to iPhone". Caption: follow for launch.
- **Why:** the joke is the format; the product *is* the punchline (proof). Built to be **sent**
  to the squad chat.

### ★ 2. "Sunday night board"
- **Audience:** competitive trainers who check numbers.
- **Trigger:** rivalry and FOMO. The crown is 3,501m away.
- **Hooks:** a) `pov: it's sunday, 9:47pm and you're #2` · b) `3,501m between you and #1. it's
  sunday night.` · c) `rowers who check the club board before bed:`
- **Script (20 s):** hook → weekly volume board, Kit #1 with crown → "the gap: 3,501m" (the
  app's own "…to move into #1" line) → illustrated monitor counts to 5,000m: "one 'easy' 5k
  later…" → board flips, you #1, "You lead this group" → "kit has 7 days to reply 😈" → end
  card "weekly erg boards for your club".
- **CTA:** follow for launch; comment-bait in caption ("tag your Kit").
- **Why:** tagging a rival is a built-in share. Shows the club-scoped board, the app's sharpest
  difference from worldwide rankings.

### ★ 3. "The PB line"
- **Audience:** novices finishing first season; anyone grinding 2k tests.
- **Trigger:** pride and progress. Seeing the line go down.
- **Hooks:** a) `7:32.6 → 6:42.9 · one 2k at a time` · b) `can you remember your first 2k
  time?` · c) `every 2k PB you've pulled. one line.`
- **Script (20 s):** hook → PB progression chart: "january: 7:32.6" → "august: 6:42.9" → current
  PB card "49.7 seconds faster 💜" → dated PB list "every PB, dated and kept" → Test results,
  "Best in your group": "11.7s to catch kit 👀" → end card "watch your 2k come down".
- **CTA:** follow for launch; caption asks "what was your first 2k?" (comment prompt).
- **Why:** aspirational and saveable; the question hook (b) prompts comments.
- **Note:** variant a's numbers belong to the fictional demo rower; "Demo rower · fictional
  data" is on screen from the first frame.

### 4. "The erg face" (filmed + app)
- **Audience:** all rowers. **Trigger:** self-deprecating humour.
- **Hook:** `the monitor says 6:41. the front camera says I'm dying.`
- **Script (15 s):** last 20 s of a real 2k (side angle, rate climbing) → collapse off the
  handle → phone up, Log screen, shutter → cut to the posted dual photo: monitor on one side,
  wrecked face in the corner → "two cameras. no hiding."
- **Shots:** filmed. Phone on a tripod side-on to the erg (0–8 s); a close-up of the screen
  recording of a real Log capture (8–12 s); the real post in the feed (12–15 s).
- **Sound:** heavy breathing + the erg flywheel (original audio), then a beat drop on the
  photo reveal.
- **CTA:** follow for launch. **Why:** the front camera is the joke, and only Rowing Pals posts
  both photos at once.
- **Needs:** a real rower who agrees to be filmed and posted, plus a real-device screen
  recording.

### 5. "Rate the erg faces" (tier list, user content)
- **Audience:** a club's own members, then their friends. **Trigger:** banter.
- **Hook:** `ranking our squad's 2k faces. no mercy.`
- **Script (18 s):** tier list (S–D), each front-camera face slotted in with a 2-word verdict;
  ends on the coach's face, ranked S.
- **Shots:** real posts, used **only with every pictured rower's written OK**.
- **Sound:** a phonk or meme-style track (check the trending sounds). **CTA:** "comment your
  club and we'll rank yours."
- **Why:** comments plus tags. Run it on a club's own account as a launch partner.

### 6. "Novice vs senior 2k day" (expectation / reality)
- **Audience:** novices in their first season. **Trigger:** relatable nerves, reassurance.
- **Hook:** `novice 2k day vs senior 2k day`
- **Script (16 s):** split screen. Novice: 3 bananas, 40-minute warm-up, asks the cox the plan
  6 times. Senior: arrives 2 minutes late, "it's just a 2k". Ending: "on Rowing Pals, novices
  rank with novices." Then Rankings with the Novice filter.
- **Shots:** filmed skit (two people, a boathouse erg room) + Filters sheet screen recording.
- **CTA:** follow for launch. **Why:** speaks straight to the novice / senior split the app
  already has, and makes the leaderboard feel fair.

### 7. "What your 2k split says about you" (everyday post, list)
- **Audience:** rowers and erg-curious gym-goers. **Trigger:** identity and banter.
- **Hook:** `what your 2k split says about you:`
- **Script (12 s, rendered):** 2:00+ "you're here for the socials"; 1:50 "you own a
  rowing-themed mug"; 1:40 "you've said 'legs, body, arms' to a stranger"; 1:35 "you have a
  spreadsheet"; final card: "find out where you stand in your club" with a Rankings flash.
- **Sound:** fast pop or house; pop cue per line.
- **CTA:** "comment your split." **Why:** comment bait plus a share; cheap to make (text only).
- **Watch:** keep jokes about habits, never about bodies or ability.

### 8. "The weekly crown" (episodic series with a real club)
- **Audience:** one partner club, then rowers following the story.
- **Trigger:** suspense and loyalty (who wins this week?).
- **Hook:** `week 3: can anyone stop [real rower]?` (real names only with consent)
- **Script (20 s):** Sunday-night screen recording of the real club's weekly volume board, one
  line per top-3 rower, a filmed reaction from the winner, next week's tease.
- **Shots:** real board recording + a phone selfie reaction.
- **CTA:** "follow for next week's crown." **Why:** series build return viewers and follows.
- **Needs:** the app live (or TestFlight) at a partner club, with consent.

### 9. "Coach is watching" (coaching humour)
- **Audience:** rowers with a coach; coaches.
- **Trigger:** busted-but-funny.
- **Hook:** `logged it as UT2 at rate 27? your coach can see that.`
- **Script (15 s):** rower tags a session UT2 → cut to coach's phone: the Coaching rower page
  shows the Pace Engine's "Likely mis-tagged" flag → coach's eyebrow raise → "coaches see their
  squad's training. read-only."
- **Shots:** filmed skit + screen recording of Coaching Phase 1 (built).
- **CTA:** "coaches: follow for launch." **Why:** reaches the coaches, who can bring whole squads.
- **Check before filming:** the exact flag wording on a real device.

### 10. "Don't break the streak" (day in the life)
- **Audience:** habit builders; early-morning outing rowers.
- **Trigger:** discipline and FOMO about the 🔥.
- **Hook:** `5:40am. it's raining. 11-day streak.`
- **Script (18 s):** alarm, kit bag, dark walk to the boathouse, erg session, photo post, the 🔥
  on the avatar and the Profile consistency grid filling in.
- **Shots:** filmed (a real rower's morning) + Profile screen recording.
- **Sound:** lo-fi building to house at the post moment.
- **CTA:** follow for launch. **Why:** an aspirational routine with saves; shows streaks and
  the grid.

---

## 4. Which three were produced, and why

| Rank | Concept | Why it won |
|---|---|---|
| 1 | Receipts | Strongest share mechanic (sent to the squad chat), humour first, and the product *is* the payoff. |
| 2 | Sunday night board | Rivalry plus tagging, and it shows the clearest difference (club-scoped boards). |
| 3 | The PB line | Progress and pride, with a comment-prompt hook. It covers the PB features the other two don't. |

These three can be made **without filming anyone**. Concepts 4, 5, 8 and 10 depend on real
training footage, which is the priority request in the brief. They are the next batch once
you can film (shot lists above).

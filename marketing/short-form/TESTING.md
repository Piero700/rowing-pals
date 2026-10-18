# Testing plan

Nothing here assumes a result. No video is "working" or "viral" until the numbers below say
so, and with one new account the first numbers will be small and noisy. Treat early results as
direction, not proof.

## What we're testing

1. **Hook** (first test): within each video, variants a / b / c differ **only in the first
   2.6 s**, so any difference in early drop-off comes from the hook.
2. **Concept** (second test): Receipts vs Sunday board vs PB line. This tells us which
   *reason to care* (proof, rivalry, progress) pulls best.
3. **Later:** rendered (these three) vs filmed (concepts 4, 5, 8, 10), and length (15 s vs 25 s).

## Metrics, in order of importance

| Metric | Where to read it | Why it matters |
|---|---|---|
| **3-second hold**: % of viewers still watching at 3 s | TikTok retention graph; Reels "skip rate" / retention; Shorts "stayed to watch" | The hook test. The only metric the hook alone controls. |
| **Average watch time** and **completion rate** (% who reach the end) | All three: per-video analytics | The strongest ranking signal on TikTok (watched to the end) and Instagram (watch time). |
| **Shares / sends per 1,000 views** | TikTok shares; Instagram "sends"; YouTube shares | Instagram says sends drive reach to non-followers. Receipts and Sunday board are built to be sent. |
| **Profile visits per 1,000 views** | TikTok and Instagram insights | Intent: the viewer wanted to know what the app is. |
| **Follows per 1,000 views** | All three | Our pre-launch conversion: "follow for launch". |
| **Attributable installs** | App Store Connect → App Analytics → campaigns (after launch) | The real goal. Not measurable until the app is live; see below. |

Likes and comments are recorded but not used to pick winners. Exception: concept 3 (b) asks for
comments, so count them there.

## How to run the hook test

- **Instagram:** post each variant as a **trial reel**, which shows it to non-followers first.
  This is the cleanest A/B on any of the three. Check that trial reels are available on your
  account.
- **TikTok:** no built-in A/B. Post one variant every 2–3 days at the same time of day, same
  caption, same sound. Don't post two variants of the same video on one day: TikTok avoids
  showing a viewer two near-identical videos back to back.
- **YouTube Shorts:** post the best TikTok/Instagram variant only, once the hook test has a
  winner.
- **Read results** at 72 hours, and only once a variant has **at least 1,000 views**. Below
  that, note the numbers but don't decide.
- **Pick a winner** only if its 3-second hold is **at least 5 points higher** (e.g. 62% vs 57%)
  *and* its completion rate is no worse. Otherwise call it a tie, keep the cheaper hook
  pattern, and test a new hook against it.
- Re-test any winner once. One good post can be luck; two in a row is a pattern.

## Attributing installs (from launch day)

1. In App Store Connect, create a **campaign link** for each platform and video, e.g.
   `ct=tt_receipts_a`, `ct=ig_receipts_a`, `ct=yt_receipts`, and put it in that platform's bio
   or link sticker. App Analytics then reports downloads per campaign. It only counts people who
   agreed to share analytics with developers, so treat it as a lower bound.
2. Add a one-tap **"How did you hear about us?"** question at the end of onboarding (TikTok /
   Instagram / YouTube / a friend / my club / other). This catches the many installs that come
   from a friend sending the video, not from the link. *This is a new app feature: ask the
   user before building it.*
3. Weekly: installs per 1,000 views per platform, and per concept.

## Until launch

The CTA is "follow for launch", so the conversion we can measure is **follows and profile
visits per 1,000 views**. If you set up a waitlist page, add its link to each bio and count
sign-ups per platform with a `?src=` tag.

## Log

Record every post in the table below (or the plugin's `state/video-log.md`): date, platform,
file, variant, hook pattern, sound, length, then the numbers at 72 h. Leave a cell blank
rather than estimate.

| Date | Platform | File | Hook pattern | Views | 3-s hold | Avg watch | Completion | Shares/1k | Profile visits/1k | Follows/1k | Installs (campaign) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | | | |

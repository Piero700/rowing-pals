# Rowing Pals launch film: concept, narration and storyboard (for approval)

90 s · 16:9 · 1920×1080 · 30 fps · YouTube. Built with Remotion, following video-shotcraft's
guided ("co-creation") workflow. Narration by ElevenLabs.

## 1. Product brief (from the repo, not assumed)

| Item | Judgement | Evidence |
|---|---|---|
| What it is | The social and competitive layer around erg and water training for club rowers | `CLAUDE.md`, build plans |
| Audience | UK university and club rowers (novice and senior) and their coaches | decisions 24–26, 34–47 |
| Core promise | Your training, your club and your progress in one place, with proof | two-photo capture + OCR, club feed, club-scoped boards |
| Features the film may show (all merged on `main`) | Two-photo capture with on-device monitor reading and stroke-rate confirm · Following / Club feed with reactions, comments, new-PB glow · PB history line + dated PB list · "Estimated today" 2k/5k (Pace Engine) · Volume rankings (week/month/year, your group, "…m to move into #N") · Test results + "Best in your group" · Clubs (Your crew, club tests) · Coaches (read-only view of their squad) | `docs/design/v2-build-plan.md`, `coaching-build-plan.md`, Swift sources |
| Never shown | Coach-set workouts and attendance (Phases 2–3, not built), worldwide rankings (dropped, decision 17), integrations (none exist), user counts, testimonials | same |
| Status | Not on the App Store, so the CTA is **"Coming soon to iPhone"** | build plan, phase L |
| Visual language | Dark base `#101114`, cards `#1B1C21`, brand blue `#91B8FF` (interactive / CTA), lilac `#C6ADFF` (PBs), gold `#EFC37C` (#1 only), Liquid Glass surfaces, SF Pro with monospaced digits | `CLAUDE.md` palette, `DesignSystem/Tokens.swift` |
| Data | Fictional demo club **Wexmoor UBC** and invented rowers. No real users. | your instruction from the last batch |

## 2. Concept: "The number, shared"

Restraint first. The opening is all water, breath and the erg's flywheel: dark frames, one warm
practical light, slow push-ins, white type in sentence case. The problem beat stays cold and
quiet: one rower, one machine, an empty room. The reveal lifts the light. The brand-blue glow
grows out of the monitor's LCD into the app icon, and the film moves *into* the phone. From
there the screens do the talking. Each feature gets one deliberate camera move on a floating
iPhone (slow dolly, slight parallax tilt, soft reflection) and **one** interface animation that
makes it tangible: the numbers lifting off the monitor into the Review form, a reaction landing,
the PB line drawing itself, a rank row rising into place. Music is a low piano and pulse pad that
starts at 0:00 and only opens up at the reveal, ducked under every narration line. It closes on
the otter mark, "Train together." and "Coming soon to iPhone".

Brand colours keep their jobs from the app: blue for interactive and CTA, lilac for anything
personal-best, gold only for the #1 row.

## 3. Narration (163 words, ~70–78 s spoken)

Recommended voice: **Oliver, Warm British Narrator** (ElevenLabs `lo1O1Dz1Tu4FWVEPaxuT`): calm,
measured, understated. Alternatives: George (premade, warmer and older) or Nora (British,
female, confident). One take per line, so each can be timed to its shot.

| # | Line | Act |
|---|---|---|
| 1 | Every rower knows the number. | Opening |
| 2 | The split you're chasing. The 2k you can't stop thinking about. | Opening |
| 3 | But most of the work happens alone. | Problem |
| 4 | Early starts. Long pieces. Results written in a notebook, and forgotten. | Problem |
| 5 | Rowing Pals is the social side of rowing. | Reveal |
| 6 | Your training, your club and your progress, together. | Reveal |
| 7 | Finish a piece and take one photo. | Capture |
| 8 | The rear camera catches the monitor. The front camera catches you. | Capture |
| 9 | Rowing Pals reads the numbers off the screen. You just confirm the rate. | Capture |
| 10 | Then it's on your club's feed, where your crew can react, comment, and celebrate every new personal best. | Feed |
| 11 | Every test builds your history. Watch your 2k come down, and see an estimate of what you could pull today. | PBs |
| 12 | Weekly rankings show exactly where you stand in your own group, and how many metres it takes to move up. | Rankings |
| 13 | Join your club, take on its own tests, and let your coach follow the squad's training. | Clubs |
| 14 | Rowing Pals. Train together. | Close |
| 15 | Coming soon to iPhone. | Close |

## 4. Storyboard (final timings are set from the real voice durations)

| # | Time | Picture | Source | Motion / interface animation | Sound |
|---|---|---|---|---|---|
| 1 | 0:00–0:05 | Black → macro of the erg flywheel cage in low light; breath | **Footage F1** | Slow push-in, light flicker on the fan | Flywheel whirr fades in, low pad |
| 2 | 0:05–0:11 | Close-up of the monitor: split ticking down. L1 | **F2** | Rack focus from the chain to the LCD | Single soft piano note |
| 3 | 0:11–0:16 | Hands at the catch, the drive. L2 | **F3** | Slow motion 50%, then title "The number." in fine white type | Breath, chain |
| 4 | 0:16–0:22 | Wide: one rower, empty gym at dawn. L3 | **F4** | Locked-off, slow 2% zoom out (isolation) | Room tone, music thins |
| 5 | 0:22–0:28 | A page of erg scores in a notebook, then the monitor going dark. L4 | **F5** (or a typographic version: scores fade out one by one) | Light fades out | Paper, silence |
| 6 | 0:28–0:35 | The monitor's LCD glow turns brand blue, and the otter icon forms from it; wordmark "Rowing Pals". L5 | Motion design + `AppIcon` | Match-cut glow → icon, 1 s hold | Pad opens, soft swell |
| 7 | 0:35–0:40 | Three floating iPhones (Feed, Rankings, Profile) fanned in depth. L6 | **App screens S3, S7, S6** | Slow orbit, depth of field | Music rises |
| 8 | 0:40–0:45 | Log workout: viewfinder, shutter press. L7 | **S1** | Push-in on phone; shutter flash | Shutter click |
| 9 | 0:45–0:50 | Split screen: the monitor photo + front-camera inset. L8 | **S1/S2** (the real captured pair) | The two photos slide apart, then dock | Soft whoosh |
| 10 | 0:50–0:56 | Review screen: distance, time, split lift off the monitor photo and settle into fields; tap Confirm on rate. L9 | **S2** | Signature interface moment: digits travel from the photo to the form | Tick per field, tap |
| 11 | 0:56–1:04 | Club feed with the new-PB glow post; a reaction lands, comment count rises; comments thread slides in. L10 | **S3, S4** | Vertical dolly down the feed | Pop on reaction |
| 12 | 1:04–1:12 | PB history: the progression line draws itself; "49.7 faster" pill; cut to the Profile "Estimated today" card. L11 | **S5, S6** | Line draw, lilac accent | Rising tone under the line |
| 13 | 1:12–1:19 | Volume rankings: "…m to move into #1", then the row rises a place; Test results "Best in your group". L12 | **S7, S8** | Rank row rises, gold only on #1 | Low impact on the move |
| 14 | 1:19–1:25 | Your crew (club), a club test board, the coach's Rowers list. Intercut with a crew carrying a boat out. L13 | **S9, S10, S11 + F6** | Cross-dissolve between footage and phone | Music at its fullest |
| 15 | 1:25–1:30 | Otter mark, "Rowing Pals", "Train together.", then "Coming soon to iPhone" in brand blue. L14–15 | `AppIcon` | 1.5 s hold, fade to black | Resolve chord |

## 5. Assets needed from you (nothing will be made up)

**App screens (real captures).** From the simulator or your phone, logged in as a **demo
account in a fictional club** (e.g. Wexmoor UBC; no real users). iOS screen recordings
(Control Centre → Screen Recording) are best: 5–10 s each, slow scrolls. Stills are fine
otherwise:
- S1 Log workout, with a monitor in view (needs a real phone, the simulator has no camera)
- S2 Review session straight after a monitor photo: numbers filled in, Confirm on the rate
- S3 Club feed with a new-PB post (the glow) and reactions
- S4 A comments thread
- S5 PB history · 2k, with several PBs on the line
- S6 Profile, showing the 2k/5k "Estimated today" cards with a prediction
- S7 Rankings · Volume · Week, you at #2 with "…m to move into #1"
- S8 Rankings · Test results, "Best in your group"
- S9 Your crew (club page) · S10 a club test board · S11 Coaching → Rowers list (optional)

**Footage.** Your own clips: phone 4K at 24/25/30 fps, horizontal, low light is fine:
- F1 flywheel/fan close-up
- F2 monitor close-up mid-piece
- F3 hands on the handle, catch → drive
- F4 one rower alone in an erg room
- F5 a notebook of scores (optional)
- F6 a crew carrying a boat / on the water

Anyone on camera must agree to being in it. Stock footage can't be fetched here: the
environment's network policy blocks `api.pexels.com` and `pixabay.com`. If you'd rather use
stock, add those hosts under Allowed domains in the environment's network settings and give me
a free Pexels API key, or download clips yourself and drop them in.

**How to get files to me:** commit them to `marketing/launch-film/assets/` on this branch (or
any branch), or attach them in this chat.

## 6. What happens if some assets don't arrive

- **No footage:** shots 1–5 and 14 become motion design built from the brand (darkness, a slowly
  turning flywheel drawn in line, the monitor's LCD digits, water caustics in brand blue). It's
  restrained and honest, but less cinematic than real footage.
- **No real app screens:** I won't fabricate them. I can either pause the build, or (only if you
  say so) use renders of the app's own v4 design artboards with the fictional club. Those differ
  from the shipped app in places: the PB screen still shows the old "estimate will appear here"
  placeholder, and the Review screen shows the pre-Zone label picker. So they'd be labelled
  "Design preview" on screen.

## 7. Music and sound

ElevenLabs is connected for speech only (the restricted connector has no music or sound
generation). The bed and effects are therefore **original, generated locally** (a slow
piano/pad build and synthesized flywheel, shutter, tick and pop), with no licence needed. They
are ducked under the narration and mixed to −14 LUFS for YouTube. You can supply a licensed
track instead. Per video-shotcraft, the final delivery is two versions: with music, and with
SFX and voice only.

## 8. Delivery

`RowingPals-LaunchFilm-1080p30.mp4` (H.264, AAC) + a no-music version, the Remotion project
(`marketing/launch-film/remotion/`), the voice files and their measured durations, captions
(`.srt`) and every source asset. Remotion's licence is free for individuals and companies of up
to three people; larger companies need a paid licence.

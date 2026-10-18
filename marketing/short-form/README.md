# Rowing Pals: short-form videos (batch 1)

Three 9:16 promo videos, each with three opening-hook variants, for TikTok, Instagram Reels and
YouTube Shorts.

| File | Video | Length | Hooks |
|---|---|---|---|
| `out/A-receipts-{a,b,c}.mp4` | Receipts: pics or it didn't happen | 22.5 s | a POV · b quote · c question |
| `out/B-sunday-board-{a,b,c}.mp4` | Sunday night board | 20 s | a POV · b number · c callout |
| `out/C-pb-line-{a,b,c}.mp4` | The PB line | 20 s | a before/after · b question · c promise |

- `CONCEPTS.md`: research, the ten concepts, and why these three.
- `POSTING.md`: captions, titles, hashtags and posting windows per platform.
- `TESTING.md`: the hook test, metrics, decision rules and install attribution.
- `out/*.srt`: the on-screen text as caption files (upload to YouTube for accessibility);
  `out/*-cover.png`: frame-0 covers.

The MP4s (~33 MB) are **not committed** (`.gitignore`); they were sent directly. Re-render with
the commands below to get them back.

## Read before posting

- **The app screens are not screenshots from a phone.** They are renders of the app's own v4
  design artboards (`docs/design/v4/*.dc.html`), the closest thing to the built UI that this
  cloud session can produce (no Xcode or simulator here). The type is Liberation Sans, not SF
  Pro. **Before paid promotion, replace them with real simulator or device screen recordings.**
  The layouts were written so each phone can take a video instead of a still (see "Re-render").
- **Every name, club and number is fictional** (Wexmoor UBC). Each video says so on screen and
  in the caption. Nothing comes from the app's sample data or from real users.
- **The erg monitor is an illustration**, not a photo and not a Concept2 monitor. The emoji
  face stands in for the front-camera photo.
- **Only built features are shown.** Two-photo capture, monitor reading with stroke-rate
  confirmation, the club feed with reactions and the new-PB glow, weekly volume boards scoped to
  your group, PB history, and "Best in your group" are all on `main`.
- **Not on the App Store yet**, so every CTA is "Coming soon to iPhone / follow for launch".
  Re-render the end cards on launch day.
- One detail that matches the app: the rank card's gap is the difference **plus 1 m**
  (`MetresLeaderboardView.heroSentence`), so 64,900 − 61,400 shows as "3,501m to move into #1".

## Re-render

Requirements: Node 18+, ffmpeg with libx264 + aac, and the `marketing-skill` plugin
(`claude plugin marketplace add marcosmodly/marketing-skill`, then
`claude plugin install marketing-skill@marketing-skill`). Then run `npm install` in its
`scripts/video` folder. This cloud session also needed `apt-get install ffmpeg` and
`playwright@1.56.1`, to match the preinstalled Chromium.

```
python3 build/build.py      # writes the three .html pages from build/base.css + the scripts
python3 build/posting.py    # writes POSTING.md with character counts
R=~/.claude/plugins/marketplaces/marketing-skill/scripts/video/render.js
node $R A-receipts.html --stills 1,8,12,16 # preview frames
node $R A-receipts.html out/A-receipts.mp4 --variants a,b,c --cover 0
```

`render.js --check` reports "runs into another element (<img class="screen">)" and "clipped"
on the phone scenes. These are false positives: the screen image is taller than the phone and
clipped by it. Every frame was checked by eye with `--stills` instead.

The app-screen PNGs in `assets/` came from `docs/design/v4` with the fictional data swapped in
(`build/screens/`):

```
python3 build/screens/subs.py /tmp/rp-src                 # fictional-data copies of the artboards
node build/screens/shot2.js /tmp/rp-src assets            # 393x852 screens at 3x
node build/screens/tall.js /tmp/rp-src assets PBHistory Tests   # full-length scroll captures
```
(`shot2.js` names files after the source, e.g. `VolBefore.png`; `tall.js` adds `-tall`.) When
the app's look changes, swap in real simulator recordings instead.

## Sound

An original house track (124 BPM, A minor, energy 4, hook `1 3 5 3 | 6 5 3 1`) and synthesized
effects (ping, rimshot, shutter, click, pop, boom, chime), generated locally by the renderer.
Nothing to license; mixed to about −14 LUFS. **Nobody has listened to it yet.** Check it before
posting, or swap in a trending sound in-app.

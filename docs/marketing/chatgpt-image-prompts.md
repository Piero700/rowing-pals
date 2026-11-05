# Image prompts for ChatGPT

Prompts to paste into ChatGPT (image generation) for the pictures Rowing Pals needs:
- **App Store images:** the backgrounds and hero art behind the store screenshots.
- **Placeholder photos:** sample erg monitors, rowers and clubs, for demos, the store screenshots and testing the look of the Feed.

## How to use them
1. Open **chatgpt.com** and start a **new chat**. Use one chat per group below, so the pictures in a group match each other.
2. Paste the **Style block** first and send it. Then paste one prompt at a time and send it.
3. If a picture is close but not right, reply in the same chat ("same picture, but darker water"). Don't start again.
4. To save one, click the picture, then the **download** icon (top right). Name it as the prompt says, e.g. `store-bg-01.png`.
5. Put them in `docs/marketing/images/`. For the store, open each one in **Preview**: **Tools → Adjust Size…**, untick
   **Scale proportionally**, and type the exact size the prompt gives.

**Rules for every picture:**
- No real brand logos or names: no Concept2, no PM5, no university crests.
- No real or famous people.
- Every person is made up.
- Placeholder photos are for demos only. Never present them as real users' posts.
- Generated monitor photos can't be used to test the number reading. The app's reading tests use only the real photos in `Rowing PalsTests`.

---

## Style block (send this first in every chat)

```
You are making images for "Rowing Pals", an iOS app for university rowers who log indoor rowing
(erg) sessions. Visual style for everything in this chat:
- Dark, calm, premium. Base colour near-black blue-grey #101114. Cards #1B1C21.
- Accent colours, used sparingly: soft blue #91B8FF (main), lilac #C6ADFF (personal bests),
  warm amber #EFC37C (first place), mint #78D7AC (success).
- Natural, documentary photography: early morning, cold air, real gym and boathouse light,
  slight film grain. Not glossy stock photography, not neon, not "fitness influencer".
- No text, no letters, no logos, no watermarks anywhere in the image unless I ask for numbers.
- People are fictional, varied in gender and ethnicity, aged 18–24, ordinary student rowers.
Reply "ready" and wait for my prompts.
```

---

## A. App Store images

The store wants portrait screenshots of the iPhone: **1320 × 2868** (6.9-inch). Each one is a background from this group, with a
real screenshot from the simulator laid on top and a short line of text. ChatGPT makes portrait pictures at about 1024 × 1536:
make them, then resize them to 1320 × 2868 in Preview, or ask ChatGPT for "the same picture, taller, extended at the top
and bottom" first.

**A1. Background, the erg room at dawn** (`store-bg-01.png`)
```
Portrait background, 9:19.5 aspect. A university boathouse erg room just before dawn: a long row
of indoor rowing machines seen from low down at the end of the row, monitors glowing faint blue,
breath-fog in the cold air, big windows with deep blue sky. Very dark overall (mostly #101114),
the top 40% almost empty dark sky and ceiling so a phone screenshot and a headline can sit there.
Soft blue #91B8FF light spill on the floor. No people, no logos, no text.
```

**A2. Background, the river** (`store-bg-02.png`)
```
Portrait background, 9:19.5 aspect. A calm river at first light seen from a riverbank pontoon,
mist on the water, an empty rowing eight resting at the landing stage, trees as dark silhouettes.
Palette dark blue-grey with a thin band of soft blue #91B8FF in the sky. Keep the middle 60% of
the image calm and dark (a phone screenshot goes there). No people, no logos, no text.
```

**A3. Background, the team** (`store-bg-03.png`)
```
Portrait background, 9:19.5 aspect. Eight fictional student rowers in plain dark training kit
(no logos) walking away from the camera along a boathouse slipway at dawn, carrying nothing,
shot from behind and slightly low so no faces are recognisable. Very dark, moody, soft blue
#91B8FF rim light. Leave the lower half mostly dark ground for a phone screenshot. No text.
```

**A4. Background, personal best** (`store-bg-04.png`)
```
Portrait background, 9:19.5 aspect. Abstract close-up of an indoor rowing machine's chain and
handle in motion blur, very dark, with a soft lilac #C6ADFF glow as if from a screen just out of
frame. Mostly empty dark space at top and bottom. No logos, no numbers, no text.
```

**A5. Background, the coach** (`store-bg-05.png`)
```
Portrait background, 9:19.5 aspect. Over the shoulder of a fictional rowing coach holding a phone
(screen not visible, turned away) beside a row of indoor rowing machines with student rowers
mid-stroke, blurred. Dark gym, soft blue #91B8FF light. The coach's face is not visible. Leave the
top third empty and dark. No logos, no text.
```

**A6. Optional: a feature-graphic banner** (`store-banner.png`, 1024 × 500 for the web listing and social posts)
```
Wide 2:1 banner. Same dark erg room at dawn as before, the row of machines running left to right,
with the right half empty dark space for a logo. Soft blue light. No text, no logos.
```

The headline text on each store screenshot is added afterwards (in Keynote, Figma or Canva) in SF Pro. Don't
let ChatGPT write it: generated text comes out misspelt.

---

## B. Placeholder photos: erg monitors (demo only)

What the app reads off: a dark-screened rowing-machine monitor photographed straight on, showing a results table.
Use these in demos and on the Feed's sample posts only.

**B1. A single piece** (`demo-monitor-2k.png`, square, 1024 × 1024)
```
Photograph taken with a phone, straight on, of a generic indoor rowing machine performance monitor
(an unbranded black plastic unit with a grey-green LCD screen, five small buttons under it, no
logo or brand name). Slight glare and fingerprints, gym in soft focus behind it. The screen shows
a results table in a blocky LCD font:
  time      meter   /500m   s/m
  6:58.4    2000    1:44.6  30
with four rows of 500m splits under it: 1:43.2 30, 1:45.8 29, 1:46.1 30, 1:43.3 32.
Numbers sharp and legible. No other text.
```

**B2. Intervals** (`demo-monitor-4x500.png`, square)
```
Same unbranded monitor, same style. The screen shows an interval results table:
  4x500m R1:00
  time      meter   /500m   s/m
  6:12.0    2000    1:33.0
then four rows: 1:32.8 500 1:32.8 34 / 1:33.1 500 1:33.1 34 / 1:33.4 500 1:33.4 33 /
1:32.7 500 1:32.7 35. Sharp, legible LCD digits. No other text.
```

**B3. A timed piece** (`demo-monitor-30min.png`, square)
```
Same unbranded monitor. The screen shows a 30:00 piece: total 30:00.0, 7412 metres, 2:01.4 /500m,
rate 20, and five split rows of 6:00 each below. Slightly angled (10 degrees), warm gym light.
Legible LCD digits. No other text.
```

ChatGPT often gets numbers slightly wrong. Check each picture before using it, and ask again ("the second split must
read 1:45.8") until every number is right.

---

## C. Placeholder photos: rowers (demo only)

Every post in the app has two photos, taken at the same moment: the monitor from the back camera, and the rower from the front
camera. Make these in pairs with the monitors above. All the people are made up.

**C1–C6. Post-session selfies** (`demo-rower-01.png` … `-06.png`, portrait 1024 × 1536)
Send this once, then reply "next" five times, changing the person each time (see the list below):
```
Front-camera phone selfie, arm's length, slightly from above, of a fictional student rower who
has just finished a hard indoor rowing piece: flushed cheeks, sweat, damp hair, breathing hard,
a tired but happy expression, plain dark training top with no logo. Background: a dim university
erg room with other machines out of focus. Natural phone-camera look, slight grain, not retouched.
Person 1: a young woman with dark curly hair tied back.
```
For the other five, change the last line to:
1. "a young man with short red hair and freckles";
2. "a young woman of South Asian heritage with a long plait";
3. "a young Black man with a shaved head";
4. "a young East Asian woman with a short bob";
5. "a tall young man with a beard, wearing a beanie".

**C7–C9. Profile photos** (`demo-avatar-01.png` … `-03.png`, square 1024 × 1024)
```
Square profile photo of a fictional university rower, head and shoulders, relaxed smile, outdoors
by a river at golden hour, plain navy hoodie without logos, shallow depth of field. Centred so it
crops to a circle.
```
Change the person each time, as above.

**C10. A crew photo, for Season Wrapped and shared posts** (`demo-crew.png`, portrait 1024 × 1536)
```
Eight fictional student rowers and a cox, arms around each other on a boathouse slipway at dawn,
plain dark kit with no logos or crests, an eight resting on the slings behind them, misty river.
Candid, happy, a little cold. No text.
```

**C11–C12. "Photos from the session" extras** (`demo-extra-01.png`, `-02.png`, portrait)
```
Phone photo, candid: a row of indoor rowing machines after training, water bottles and towels on the
floor, morning light through windows. No people's faces, no logos, no text.
```
```
Phone photo, candid: a rower's hands on a rowing machine handle, blisters and tape on the fingers,
dark gym. No logos, no text.
```

---

## D. Placeholder pictures: clubs (demo only)

**D1–D3. Club crests** (`demo-crest-01.png` … `-03.png`, square 1024 × 1024)
```
A simple flat crest for a fictional rowing club, as a circular badge: two crossed oars with a small
wave under them, one or two colours, thick clean shapes that still read at 40 pixels, on a plain
dark #101114 background. No letters, no words, no real university or club symbols.
```
For the other two, ask for: "a heron standing in reeds instead of oars"; "a stylised boat seen from above".

**D4. Club cover photo** (`demo-club-cover.png`, wide 1536 × 1024)
```
Wide photo of a fictional riverside boathouse with green doors at dawn, boats on racks visible
inside, mist on the river, no signs, no names, no people.
```

---

## Where they go
- **Store backgrounds (A):** at 1320 × 2868, with simulator screenshots of the Feed, Log, Review, Profile,
  Rankings and the coach's Workouts laid on top. Take the screenshots in dark mode with demo data only.
- **Placeholder photos (B–D):** `docs/marketing/images/`. They aren't added to the app or to the Dev database unless you ask.
  Dev is shared with your TestFlight testers.

# Grouped rows across the whole app: test checklist

Decision 99 in `docs/design/v2-decisions.md`. Branch `t44-grouped-everywhere`. No migration needed.
Use **Coach_J** for sections 1–5 and **Piero** for section 6.

## 1. The look, everywhere
Open any few screens.
- [ ] Cards have small corners and thin edges. Nothing looks like a big bubble.
- [ ] Segmented controls (e.g. All | Done | Not yet) are compact, with small corners.
- [ ] Big buttons are rounded rectangles, with no glow under the blue ones.
- [ ] The floating tab bar and the round glass buttons look the same as before.

## 2. Workouts and Calendar
1. **Workouts** tab.
   - [ ] Today's cards end in a thin **Open notepad ›** row, and it opens the notepad.
   - [ ] Tapping the rest of the card opens the workout's results.
   - [ ] Swiping a card left still shows the red Delete. (Don't tap it unless you mean to.)
2. Open a workout.
   - [ ] The rowers are **one card** with thin lines between them. Tapping a rower opens their page.
3. **Calendar** tab.
   - [ ] The month grid is shorter than before.
   - [ ] Today's practice ends in a thin **Take register ›** row, with no spare room under it, and it opens the register.
4. Tap the people icon top right (Who's available).
   - [ ] If there are races, they're one card with thin lines between them.

## 3. The coach's forms
For each form below, check:
- labels are on the left and values on the right;
- **Save** (or Set, Add, Post) is top right, and is grey until the form can be saved;
- saving works and takes you back;
- on an existing item, the red delete or cancel row asks you to confirm.

- [ ] **Practice:** Calendar → **Add** → Practice. What (with quick picks), Place, Date, Starts, Ends, Every week (with
      Until when on), Squads, Remind rowers. Editing one in a series still asks "This practice only" or "the rest".
- [ ] **Race or event:** Calendar → **Add** → Race or regatta, or Other event. The "More than one day" switch shows **Last day**; off means one day.
      Ask who can race, and the Note.
- [ ] **Announcement:** **+** → Announcement. Heading, the details, **On the Feed for** (a menu; Custom shows **Until**),
      Send an alert.
- [ ] **Term dates:** Profile → Attendance totals → the terms button. Each term is its own card. Swiping left deletes it, **Add a term** adds one, and **Save** top right saves.
- [ ] **Challenge:** **+** → Challenge. **Kind** is a menu. Metres for a personal target or club total, a ticked list of squads for squad vs squad.
- [ ] **Erg event:** **+** → Erg event. Distance | Time, and the time types with the colon put in for you.
- [ ] **Squad:** Rowers → the people icon → a squad. Name row, Save top right, red Delete squad.
- [ ] **Water session:** **+** → Water session. Title, Meet at, Date, Starts, Ends, The plan. **Save session** still turns to ✓ Saved,
      and **Send to N rowers** still sends.
- [ ] **Boat:** on a water session, open a boat. Boat name is a row, and Keep in Saved boats is a switch row. Crewing works as before.

## 4. Attendance totals
Profile → Attendance totals → the custom span.
- [ ] **From** and **To** are rows, and the numbers change when you change them.

## 5. Swipe back
- [ ] Swipe from the left edge on each form above. Each goes back.

## 6. The rower's side (Piero)
I could only check these as drawings, not on a rower's account, so please look closely.
- [ ] **Feed:** posts have small corners and read clearly, and reactions, comments and share work.
- [ ] A coach's scores card ends in a thin **Log your session ›** row that opens Log.
- [ ] An erg event's card ends in a thin **Log your 2k ›** row that opens Log.
- [ ] **Rankings:** a test's board is **one card** with thin lines between rows, and the top three keep their tint.
- [ ] **Follow requests:** one card, and Accept and Decline work.
- [ ] **Season Wrapped:** **Your dates** shows From and To as rows.
- [ ] **Profile** and **Log** read clearly, with nothing cut off or overlapping.

## 7. Light mode
- [ ] Settings → Appearance → Light: the card edges and the lines between rows are visible, on Workouts, a form and the Feed.

# Coach version, phase CV2 (Calendar and attendance) — test checklist

Decisions 62, 68 and 69 in `docs/design/v2-decisions.md`; plan in `docs/design/coach-version-build-plan.md`.
Branch `t41-coach-version`. **Don't merge until every box you can tick is ticked on your phone.**
Phase CV1's checklist (`docs/testing/coach-version-phase1.md`) still needs doing too; do it first or
alongside this one.

You need two accounts in the same club, and ideally a second rower:
- **Coach_J** — "Coach only" and made a coach (already set up on staging).
- **Piero** — rows, in the same club.

Tip: one phone is enough. Sign out (coach: picture → Log out; rower: Profile → Settings → Log out)
and sign in as the other account when a step says so.

## 0. Run the migrations on staging (do this first)
1. Open https://supabase.com/dashboard in your browser and sign in.
2. Click the **staging** project (the one whose URL starts `gdcgqesjzmbctyafdutn`).
3. If you haven't yet run phase CV1's file: left sidebar → **SQL Editor** → **+ New query**. Open
   `docs/migrations/2026-10-16-coach-version.sql` in Xcode or TextEdit, press **Cmd+A**, **Cmd+C**,
   click into the query box, press **Cmd+V**, click **Run**. Expect **Success. No rows returned**.
4. Left sidebar → **Database** → **Extensions**. Type `pg_cron` in the search box. If its switch is
   off, click it and click **Enable extension**. (The two-hour reminders need it.)
5. Left sidebar → **SQL Editor** → **+ New query**. Open `docs/migrations/2026-10-16-calendar.sql`,
   **Cmd+A**, **Cmd+C**, click into the query box, **Cmd+V**, click **Run**.
   - Expect a result table with one row (the reminder job's number), or **Success**. Either is fine.
   - Any red error: stop, take a screenshot and send it to Claude.
6. The alert function is already deployed to staging (Claude did this).

## 1. Install the build
1. Plug in your iPhone. In Xcode, at the top choose the **RP Dev** scheme and **your iPhone**.
2. Press **Cmd+R** and wait for the app to open on your phone.

## 2. The coach's Calendar (sign in as Coach_J)
- [ ] The bar at the bottom reads **Rowers · Workouts · Calendar** with the blue **+** beside it.
1. Tap **Calendar**.
- [ ] Big title **Calendar**; top right a round button with a person-and-tick icon (Who's available)
      and your picture.
- [ ] A month card: **October 2026**, arrows either side, weekday letters starting **M**, and today
      (16) in a blue circle.
- [ ] Under it: **TODAY · FRI 16 OCT** and **TOMORROW · SAT 17 OCT**, each with an **Add** button and
      "Nothing on…". No red error text.
2. Tap the **›** arrow, then **‹**: the month changes to November and back.
3. Tap **23** in the month.
- [ ] The section below changes to **FRI 23 OCT** with its own **Add**.

### 2a. A weekly practice
1. Tap **TODAY**'s **Add**.
- [ ] A sheet: **Add to Fri 16 Oct**, Cancel, and four rows — **Practice**, **Land session**,
      **Race or regatta**, **Other event** — all visible without scrolling.
2. Tap **Practice**.
- [ ] **New practice** opens: What (with Water · Erg · Circuits · Weights · Land training), Date,
      Place, Starts / Ends, SQUADS (Whole club and your squads), REPEATS (Every week · On Fridays),
      REMINDER (Remind rowers, on), "N rowers are notified…", **Save practice**.
3. Tap **Erg**, set **Starts 18:00**, **Ends 19:30**, Place `Erg room`, leave Whole club.
4. Turn on **Every week**. **Until** appears: pick a date about four weeks ahead.
5. Tap **Save practice**.
- [ ] The editor closes. Today shows the practice: **18:00 / 19:30**, **Erg**, Erg room, its counts
      and "every Friday". The month shows a dot on today and on each Friday until your Until date.
- [ ] (Piero's phone, or later when you sign in as Piero) an alert **New practice** — "Coach_J: Erg ·
      Fri 16 Oct, 18:00 · Erg room · every week. Tap to say if you can make it."

### 2b. Edit and cancel
1. Tap the practice card.
- [ ] **Edit practice** opens with everything filled in, REPEATS showing Every week and the Until
      date (both greyed: a series keeps its weeks), and two red buttons at the bottom:
      **Cancel this practice** and **Cancel the whole series**.
2. Change **Ends** to 19:45 and tap **Save practice**.
- [ ] A choice: **This practice only** / **This and the rest of the series**. Pick **This and the rest
      of the series**.
- [ ] Back on the Calendar the practice ends 19:45; tap next Friday in the month: that one ends
      19:45 too.
3. Tap next Friday's practice → **Cancel this practice** → **Cancel practice**.
- [ ] It disappears from that Friday (or shows as cancelled); the Fridays after it are still there.

### 2c. A race
1. Tap **31** in the month (Sat 31 Oct) → **Add** → **Race or regatta**.
- [ ] **New race or event** opens with **Race or regatta** chosen, Name, First day 31 Oct, Last day
      **Same day**, Place, SQUADS, Note, **Ask who can race** (on), **Add to calendar** (greyed until
      there's a name) and "N rowers in the club are told."
2. Name `Norwich Autumn Head`, Place `River Wensum`, Note `Entries close Mon 26 Oct.`
3. Tap **Same day**: it turns into a date picker; pick 1 Nov. Tap **Same day** under it: back to one
   day.
4. Tap **Add to calendar**.
- [ ] Sat 31 Oct has a flag; its section shows **Norwich Autumn Head**, "Sat 31 Oct · River Wensum"
      and "0 can race · 0 can't · N no answer". It's also under races coming up.
- [ ] (Piero) an alert with the race's name and "Can you race? Tap to answer."

## 3. The rower's side (sign in as Piero)
- [ ] The bar reads **Feed · Rankings · Calendar · Profile** with the Log button.
1. On **Feed**, under any workout card:
- [ ] A **practice card**: a date tile (FRI 16), **Erg · 18:00**, "Erg room · Whole club", a **›**,
      and **Available · Can't** with neither chosen.
2. Tap **Available** on the card.
- [ ] It stays chosen. Pull down to refresh: still chosen.
3. Tap **Calendar**.
- [ ] **This week · Next week** (Next week chosen) and a line with the dates and "UEA Boat Club's
      weeks start on Monday".
- [ ] A banner "Say which sessions you can make" with **Available for the other N** (if any are
      unanswered), a card per day with **Whole day** and each session, and **Races and events**
      with Norwich Autumn Head and **Available · Can't**.
4. Tap **This week**: today's Erg shows **Available** (the answer from the Feed).
5. On next week's day, tap **Whole day → Can't**.
- [ ] Every session that day switches to Can't, and the line under Whole day reads "Can't make it".
6. Tap the session's name (left side).
- [ ] **Practice** opens: date tile, Erg, Weekly · every Friday, time, place, Set by Coach_J, YOUR
      ANSWER with Can't chosen and a **Reason (optional)** box. Type `Exam`, tap **Save** (or Return).
- [ ] From 30 minutes before the start: a **Check in** button (try it on today's practice if it's
      within the window).
7. Back, tap the race card's name (left side).
- [ ] **Race** opens: Race chip, name, "Sat 31 Oct · River Wensum · Whole club", the note,
      **CAN YOU RACE?** with Available · Can't. Choose **Can't**, type `Family wedding`, tap **Save**.
8. Close the app fully and reopen: the answers are all still there.

## 4. Register, totals and Who's available (sign in as Coach_J)
1. **Calendar** → today's practice → **Take register**.
- [ ] **Register**: the practice and its present / late / absent / excused counts, the note about
      "Suggested", **WHOLE CLUB · N**, and a row per rower: Piero says "Said available" (plus
      "checked in HH:MM" if he checked in, or "posted a session today" if he posted one); each row
      has **Present · Late · Absent · Excused**.
- [ ] Starting marks: checked in → Present; posted a session today → Present with a blue
      **Suggested**; said Can't → Excused; said Available but did neither → Absent; no answer → none.
2. Mark Piero **Present** and tap **Save register**. Reopen it, change him to **Late**, save, reopen.
- [ ] His row now says "You changed Present → Late at HH:MM".
3. Tap your **picture** → **Attendance totals**.
- [ ] **Attendance**: "Current term · No term set for today" with **Edit dates**, and **This term ·
      4 weeks · Custom**.
4. Tap **Edit dates** → **Add a term**. Name `Autumn`, first day 29 Sep, last day 5 Dec → **Save
   terms**.
- [ ] The card reads "Autumn · 29 Sep – 5 Dec". BY SQUAD and BY ROWER (lowest first) show
      percentages; Piero shows 100% (Late counts as attended), "1 of 1".
5. Tap **4 weeks** and **Custom** (two date pickers appear): the lists update.
6. Tap Piero's row: his rower page opens.
- [ ] Near the bottom: **ATTENDANCE · THIS TERM** "1 of 1", a light-green **L** square and the key
      "P Present L Late A Absent E Excused".
7. Back to the tabs → **Rowers**.
- [ ] Piero's card's attendance figure now counts the practice as well as set workouts.
8. **Calendar** → the top-right **Who's available** button.
- [ ] **Who's available**: This week · Next week, "dates · N of M rowers have answered · All squads",
      AT A GLANCE with a row per session (time, what, a blue bar and "N ✓ · N ✗"), then the chosen
      session's **Available** (with side), **Can't make it** (with "Exam"), **No answer yet**, and
      RACES with Norwich Autumn Head.
9. Tap another session in At a glance: it highlights and the lists below change.
10. Tap the race (in Who's available or on the Calendar).
- [ ] **Race**: counts (can race / can't / no answer) and the three lists — Piero under **Can't
      race** with "Family wedding" — and **Edit race**.
11. **Edit race** → change the note → **Save changes**: the race page shows the new note.
    Then **Edit race** → **Delete race** → **Delete**: you're back on the Calendar and it's gone.

## 5. Week starts on (Coach_J)
1. Picture → **Settings**.
- [ ] Under Appearance: **CLUB · COACHES** → **Week starts on** "For all of UEA Boat Club: calendars,
      availability and weekly totals." with **Monday · Sunday**, and "Only coaches see this. Rankings
      and streaks still run Monday to Sunday."
2. Tap **Sunday**, close Settings, go back to the tabs.
- [ ] Calendar's weekday letters now start with **S**; Who's available's weeks run Sun–Sat.
- [ ] (Piero) his Calendar's weeks run Sunday to Saturday, and the line says "weeks start on Sunday".
3. Set it back to **Monday**.
- [ ] Piero's Settings has **no** Club · coaches section (he isn't a coach).

## 6. Reminders and alert taps (Piero's phone)
1. As Coach_J, add a practice starting about **2 hours 10 minutes from now**, with Remind rowers on.
2. As Piero, answer **Available** (or leave it unanswered).
- [ ] Within about 15 minutes of the two-hour mark, Piero gets **Practice in 2 hours** — "Erg ·
      HH:MM · Erg room".
- [ ] Tapping it opens that **Practice** page over whatever was showing.
3. As Coach_J, cancel that practice.
- [ ] Piero gets **Practice cancelled**; tapping it opens the practice saying the coach cancelled it.
4. (Optional) Piero: Settings → Notifications → turn **Practice reminders** off; repeat step 1: no
   reminder arrives.

## 7. Database checks (optional)
If you'd like to check the rows behind any of this in the SQL editor, send Claude a screenshot of
the **Table Editor → practices** table (or say which practice) and Claude will write the SQL with
the ids filled in.

## What's built beyond the canvas or brief — please check you're happy with these
1. **What** on the practice editor (a title such as Erg, with quick picks); the calendar shows it
   instead of "Practice".
2. A **Whole club** pill in Squads on the practice and race editors (none chosen = whole club).
3. The rower's **Race** page (Can you race? with a reason only coaches see), opened from a race in
   their Calendar or its alert. The canvas only has the coach's race page.
4. **Term dates** editor behind Edit dates (name, first and last day; add, delete).
5. Attendance totals: **Custom** shows From / To pickers; tapping a rower opens their page.
6. Who's available and the race page: tapping a person opens their page; lists longer than eight
   show "and N more", which opens the rest.
7. The register's starting marks (Excused for "Can't", Absent for "said available, did neither")
   and its change line naming the coach who changed it.
8. A rower's attendance strip says **last 8 weeks** when no term dates cover today.
9. The **New practice** alert (once per practice or series).
10. Coaching's weekly totals (behind target, the 8-week charts) follow the club's week start.
11. The register shows every rower (the canvas shows six and "Showing 6 of 12").

## Not in this phase
- **Plan boats for this session** (Who's available) and **Crew boats for this race** (race page)
  come with Boats in phase CV3, as does a water session from Add.
- The canvas shows "Cox" as a side; the app's sides are Stroke side, Bow side and Both (CV1).

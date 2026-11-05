# Editing a land session, reps from the pieces, and the grouped-rows style: test checklist

This is decision 97 in `docs/design/v2-decisions.md`. Branch `t42-coach-notepad`. You can test it together with the NP3
and NP4 checklists. Use the account **Coach_J**.

## 0. Run the edit migration on the Dev project (do this first)
Until you run it, **Save** on an edited workout shows a red error. Setting a new workout works without it.
1. Open **supabase.com**, sign in, and click the **Dev** project.
2. In the left sidebar, click **SQL Editor**, then **+ New query**.
3. In Finder, open `docs/migrations/2026-11-05-edit-workout.sql`. Press **Cmd+A**, then **Cmd+C**. Click into
   the query box and press **Cmd+V**.
4. Click **Run**. You should see **Success. No rows returned**. If you get a red error, take a screenshot and send it to Claude.
5. **Before the App Store build:** run it on the production project too.

## 1. Setting a new land session
Tap the blue **+** at the bottom right, then **Land session**.
- [ ] The header reads **‹ · New land session · Set**. **Set** is grey and can't be tapped.
- [ ] Three cards, in this order:
  - **PIECES** with **+ Add piece**, and "Each piece is a column on the notepad and the results." under it.
  - **Title · Date · Time (Add) · Zone · For**, and "N rowers get “New workout from your coach”." under it.
  - **Test day** and **Notes for rowers**.
- [ ] The cards have small corners and thin edges, and each row is a label on the left with its value on the right.
1. Tap **+ Add piece**.
   - [ ] The sheet reads **Cancel · Add piece · Done**, then **Distance | Time**.
   - [ ] One card with **Distance** "2000 m" in grey, and **Reps** with − and +.
   - [ ] **TARGETS · OPTIONAL**: **Rest** "None", **Rate** "From – To", **Split** "Auto /500m", and the
         Pace Engine note under it.
2. Type **500** for the distance, tap **+** three times so Reps shows **4**, then tap **Done**.
   - [ ] The Pieces card shows **500m × 4** and "Each rower's own target split", with **+ Add piece** under it.
   - [ ] The **Title** row now shows **4 × 500m** in grey. That's the title the app writes for you.
   - [ ] **Set** turns blue.
3. Tap the piece to open it again.
   - [ ] It opens as **Edit piece**, with your values and a red **Remove piece** row at the bottom.
4. Tap the **Title** row and type your own title, e.g. "Sprint session".
   - [ ] What you typed replaces the grey title. Clear it and the grey "4 × 500m" comes back.
5. Turn on **Test day**.
   - [ ] **Zone** disappears, and a **Test** row ("Choose" in blue) appears. Turn it off again.
6. Change **For** to **Squads**.
   - [ ] A **Squads** row appears with "Choose squads" in blue, and **Set** goes grey.
   - [ ] Tap it. A list opens: tap a squad, the blue tick appears, then tap **Done**. The row shows the squad's
         name, and **Set** turns blue again.
7. Tap **Time**, then **Add**. A time appears with a ✕. Tap the ✕ and it goes back to **Add**.
8. Tap **Set**.
   - [ ] The screen closes and the workout is under Workouts → Today, called **4 × 500m** (or your own title).

## 2. The pieces decide the reps
1. Open the notepad of the workout from step 1.
   - [ ] The Scores table has **4** columns, one per rep.
2. Set a workout with **no pieces**, just a title like "4 x 500m" typed in the Title row.
   - [ ] Its notepad has **one** column. The title no longer decides the reps.

## 3. Editing a workout
1. Workouts → tap a workout. On its results screen:
   - [ ] Top right: **Edit** in blue, beside the round pencil (the notepad).
2. Tap **Edit**.
   - [ ] **Edit land session**, filled in with the workout's pieces, title, date, time, zone, who it's for,
         test day and notes. **Save** is top right.
   - [ ] Under the second card: "Saving changes doesn't alert anyone again."
3. Change something, such as adding a piece, changing the zone and editing the notes, then tap **Save**.
   - [ ] You're back on the results screen, and it shows the changes straight away.
   - [ ] Nobody gets a "New workout from your coach" alert.
   - [ ] The notepad still has the scores you'd written, and now has a column for any new rep.
4. Swipe from the left edge on the edit screen.
   - [ ] It goes back without saving.

## 4. Light mode
- [ ] Settings → Appearance → Light: the land session screen and the piece sheet read clearly, and the card
      edges and the lines between rows are visible.

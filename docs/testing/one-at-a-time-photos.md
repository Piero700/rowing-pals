# Monitor and second photo one at a time: phone test checklist

This is decision 103 in `docs/design/v2-decisions.md`, on branch `claude/angry-leavitt-cbf55f`.

**Why this needs your phone:** the simulator has no camera. It could only check how Log and Second photo look, that the choice is remembered, and that Skip reaches Review. Sections 2 to 7 have never been run. That includes taking photos, flipping, upright photos, posting and the Feed.

No SQL to run, and nothing to change in Supabase.

## 0. Put the build on your iPhone
1. Plug in your iPhone and unlock it.
2. In Xcode, click **File › Open**, go to `Rowing Pals/.claude/worktrees/angry-leavitt-cbf55f`, click `Rowing Pals.xcodeproj`, then click **Open**.
3. At the top of the Xcode window, click the device name and choose your iPhone.
4. Press **Cmd+R** and wait for **RP Dev** to open on the phone.
5. Sign in with your test rower account. Don't use a coach-only account, because it doesn't log sessions.

## 1. The Log screen
1. Tap the **Log** button.
   - [ ] Under the camera you see the caption, the **Selfie** switch, then **Together | One at a time**.
2. Tap **Together**.
   - [ ] The small front camera preview shows, the flip button shows, and the caption reads **Front + rear · No time limit**.
3. Tap **One at a time**.
   - [ ] The camera restarts on the back camera. There's no small preview and no flip button.
   - [ ] The caption reads **Monitor first · No time limit**.
4. Turn **Selfie** off.
   - [ ] **Together | One at a time** disappears, and the caption reads **Monitor only · No time limit**.
5. Turn **Selfie** back on.
   - [ ] **One at a time** is still chosen.
6. Swipe up from the bottom of the phone, swipe **RP Dev** away to close it, open it again, and tap **Log**.
   - [ ] **One at a time** is still chosen.
7. Tap **Help**.
   - [ ] There's a **One at a time** item that reads correctly. Swipe the sheet down to close it.

## 2. Two photos, with a gap
1. In **One at a time**, point the phone at your erg monitor and tap the shutter.
   - [ ] **Second photo** opens with your monitor photo small in the corner, and **Skip** top right.
   - [ ] It's on the **back** camera and the caption reads **Now your surroundings · No time limit**.
2. Wait at least two minutes with the app open.
   - [ ] The camera is still live and the monitor photo is still there.
3. Tap the flip button.
   - [ ] It changes to the **front** camera, upright, and the caption reads **Now your face · No time limit**.
4. Tap flip again.
   - [ ] It's back on the back camera, upright.
5. Flip quickly five times.
   - [ ] No freeze, no black preview and no error.
6. Tap the shutter.
   - [ ] **Review session** opens with your monitor photo and its numbers read.

## 3. Post it and see both photos
1. On Review, fix any wrong numbers and scroll down.
   - [ ] **Include on leaderboards** is there and on.
2. Tap **Post session**, then find the post on the **Feed**.
   - [ ] The monitor photo is large with your second photo small in the corner, both upright.
3. Tap the small photo.
   - [ ] They swap. Tap it again to swap back.
4. Tap the post to open its page.
   - [ ] Both photos are there, and tapping the small one swaps them.
5. Open **Rankings** and find your metres.
   - [ ] The session counts, the same as a together shot.
6. **Repeat sections 2 and 3 with a face photo:** flip to the front camera and take the second photo.
   - [ ] It's upright and looks the same way round as a face photo from **Together**. If one looks mirrored against the other, tell Claude.

## 4. Skip
1. Take a monitor photo in **One at a time**, then tap **Skip**.
   - [ ] **Review session** opens with the monitor photo.
2. Post it.
   - [ ] The Feed shows the monitor photo with no small photo and no empty box.
   - [ ] The session counts on **Rankings**.

## 5. Going back
1. Take a monitor photo, then swipe from the left edge on **Second photo**.
   - [ ] You're back on Log, the camera is live, and the **white shutter** shows, not a spinner.
2. Take a new monitor photo.
   - [ ] **Second photo** shows the new one in the corner.
3. Take the second photo, then swipe from the left edge on **Review session**.
   - [ ] You're back on **Second photo**, the camera is live, and the white shutter shows.
4. Take another photo.
   - [ ] Review opens. After posting, the Feed shows this latest second photo.

## 6. Leaving and closing the app
1. Take a monitor photo so you're on **Second photo**. Press the side button to lock the phone, wait a minute, and unlock it.
   - [ ] The camera comes back and the monitor photo is still there.
2. Swipe up to the home screen, open another app, then come back.
   - [ ] Same again.
3. Swipe up from the bottom and swipe **RP Dev** away to close it, then open it again.
   - [ ] The draft is gone and nothing was posted. This is expected.

## 7. Nothing else has changed
1. Tap **Together**, then the shutter.
   - [ ] Both photos are taken at once and Review opens without a Second photo screen.
2. On Review, tap **Add photo**, then take a photo.
   - [ ] It works as before and adds a piece.
3. On Log, tap the library button and choose a monitor photo.
   - [ ] Review opens straight away, and the session doesn't count on leaderboards, as before.
4. **Coach account:** open a notepad and scan a monitor.
   - [ ] The scan still works, because its camera code was touched by a rename.
5. **Settings › Logging › Selfie with each session:** turn it off, then open Log.
   - [ ] Selfie starts off. Turn it back on in Settings afterwards.

If anything fails, take a screenshot and send it to Claude with the section and step number.

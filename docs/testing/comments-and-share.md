# Comments thread and share card — test checklist

Decision 32 in `docs/design/v2-decisions.md`. No migration: it uses the existing `comments` and
`reports` tables. Run on the **staging** build (your phone or the simulator).

## 1. Comments thread from the feed
- [ ] On any feed card, tap the **N comments** pill (bottom left). Expect a full screen titled
      **Comments** with a back button, "Name · workout" under it, and the **Say something…** box at
      the bottom. With none yet: "No comments yet. Say something to start the conversation."
- [ ] Type a comment and tap the blue **↑** (or the keyboard's **send**). It appears at once.
- [ ] Tap **‹** back. The card's pill now reads one more comment.
- [ ] Type a rude word (one the app blocks) and send. Expect the red line "That comment isn't
      allowed. Please rephrase it." above the box, and nothing posted.

## 2. Live updates (needs a second account on another device)
- [ ] Keep the thread open on one phone; comment on the same post from the other account. The
      comment appears without refreshing.

## 3. From the workout screen
- [ ] Open a post with **4 or more** comments (add some in step 1 if needed). Under
      **COMMENTS** expect the last 3, and **View all N** on the right.
- [ ] Tap **View all N**. The thread opens on the newest comments; scroll up for the oldest.
- [ ] Comment there, go back: the new comment is also in the workout's last 3.
- [ ] Press and hold **someone else's** comment → **Report comment** → pick a reason →
      "Report sent". Your own comments have no Report option.

## 4. Share card
- [ ] On a feed card, tap the round **share** button (bottom right). Expect a sheet **Share
      workout** with a preview: the monitor photo, "ROWING PALS" top left, the workout and date,
      the rower's name, and **Distance / Time / /500m** matching the card's numbers.
- [ ] Tap **Share** → the iOS share sheet opens showing "<Name>'s workout" and the image. Save it
      to Photos (or send it to yourself) and check it looks the same, in portrait 4:5.
- [ ] Switch the app to **Light** appearance (Settings) and share again: the card stays dark.
- [ ] Share a **manual entry** post (no photo): the card shows the numbers on a plain dark ground.

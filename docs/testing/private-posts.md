# Private posts: phone test checklist

Decision 106 in `docs/design/v2-decisions.md`. Use your own account (**Piero**) on the phone, and a
second account you can sign in to (or a clubmate's phone) to check what others see.

## 1. The database change (staging)

**Done 17 Nov 2026 (by Claude):** `docs/migrations/2026-11-17-private-posts.sql` is run on staging.
Checked there: a private post can only be read by its owner; a clubmate can't read its test result;
its leaderboard metres come off and go back when it's visible again; a direct change to the flag is
ignored. Skip to section 2. The steps below are for production later.

1. Go to **supabase.com**, sign in, and open the **production** project.
2. Click **SQL Editor** in the left bar, then **+ New query**.
3. In Finder, open `Rowing Pals/docs/migrations/2026-11-17-private-posts.sql`, select everything
   (**⌘A**), copy (**⌘C**), and paste it into the query box (**⌘V**).
4. Click **Run** (bottom right).
   - [ ] It finishes with "Success. No rows returned".
5. Running it again is safe.

## 2. Install the build

From Xcode: plug the iPhone in, choose it at the top of the Xcode window, and press **▶ Run**.

## 3. Make a post private from Profile

1. Open **Profile** → **Posts**.
2. **Press and hold** one of your posts.
   - [ ] A small bubble opens with **Make private** (crossed-out eye) and, below a line, the red
     **Delete post**.
3. Tap **Make private**.
   - [ ] The bubble closes and the post's tile goes darker with a **crossed-out eye** in the middle.
   - [ ] The distance stays in the bottom-left corner.
4. Tap the tile (if the first tap does nothing, tap again — the release after a press-and-hold is
   ignored on purpose).
   - [ ] The post opens as normal for you.

## 4. Make it visible again from the post page

1. On that post's page, tap **⋯** (top right).
   - [ ] The bubble shows **Make visible** (an open eye) and **Delete post**.
2. Tap **Make visible**, then go back.
   - [ ] On Profile → Posts, the tile no longer has the eye or the darker cover.

## 5. What other people see (second account)

1. Make one of your posts private again (section 3).
2. On the second account (a clubmate or a friend who could see that post before):
   - [ ] It's gone from their **Feed**.
   - [ ] It's gone from your profile's **Posts** when they open your profile.
3. If the post set a test result (it was at a test distance or time):
   - [ ] **Rankings → Test results** → that test: your result from that post is gone (an earlier
     result of yours shows instead, if you have one).
4. If the post was on the leaderboards:
   - [ ] **Rankings → Metres**: your total for that week is lower by the post's metres.
5. If you're coached and the post was for a set workout, on your coach's account:
   - [ ] The post is gone from that workout's results.
6. Make the post visible again.
   - [ ] It's back in their Feed, on the leaderboards and in the coach's results.

## 6. What you still see

While a post is private:
- [ ] Your **Profile** stats (weekly volume, sessions, streak) still count it.
- [ ] **Profile → PBs** still shows a PB it set.

## 7. Delete still works

1. Press and hold a post you don't need, tap **Delete post**.
   - [ ] "Delete this post?" asks to confirm; **Delete** removes it.
2. Do the same with a **private** post.
   - [ ] It's removed, and your leaderboard metres for that week don't drop a second time.

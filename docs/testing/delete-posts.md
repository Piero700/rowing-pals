# Deleting your own posts — test checklist (decision 63, 2026-10-15)

## 0. Run the migration on staging FIRST
The new build writes a new column when you post, so posting fails until this has run.
1. Supabase dashboard → the **staging** project → **SQL Editor** → **+ New query**.
2. Open `docs/migrations/2026-10-15-delete-posts.sql`, select all (Cmd+A), copy (Cmd+C), paste (Cmd+V).
3. Click **Run**. Expect **Success. No rows returned**. Any red error: stop and send it to Claude.

## 1. Install the build
Plug in your iPhone; in Xcode choose the **RP Dev** scheme and your iPhone; press **Cmd+R**.

## 2. From the post itself
1. Post a throwaway session (Log → Enter session manually is fine). Note your Profile's weekly volume.
2. Open the post (tap it on the Feed or on Profile).
- [ ] Top right of the photo there's a **⋯** (on your own posts it used to be hidden).
- [ ] Tap it → **Delete post** (red) → an alert "Delete this post?" explaining what goes. **Cancel** leaves it.
- [ ] **Delete**: the post closes and is gone from the Feed and from Profile → Posts.
- [ ] Profile's weekly volume and session count drop back by that session.
- [ ] Someone else's post still shows **Report post / Block** in its ⋯, and no Delete.

## 3. From Profile → Posts
- [ ] Press and hold one of your posts: a menu with **Delete post**. Delete → same alert → it's gone.
- [ ] On someone else's profile, press and hold does nothing.

## 4. What goes with it
- [ ] Delete a post that set a **PB** on a test: Rankings → Test results no longer lists it, and your
      previous best (if any) is your PB again.
- [ ] A post linked to a coach's workout: the coach's results go back to "Not yet" for you.

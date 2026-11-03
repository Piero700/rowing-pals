# Friends: following both ways (decision 95)

Two rowing accounts are needed: **Piero** and another rower in a **different club, or no club** (call them **Rower B**), so the club rule doesn't let them in. Use the **RP Dev** build.

## 0. Database (once)

1. Supabase dashboard → the **staging** project → **SQL Editor** → **+ New query**.
2. In Finder open `docs/migrations/2026-11-03-mutual-follow-posts.sql`, Cmd+A, Cmd+C, paste into the query box, **Run**. "Success. No rows returned".

## 1. One-way follow

1. Rower B follows Piero. Piero does **not** follow Rower B.
- [ ] Piero posts a session set to **Friends**. Rower B's Feed → **Following**: the post is **not** there.
- [ ] Piero posts one set to **Everyone**: Rower B still doesn't see it (they're not in Piero's club).
- [ ] On the post screen, under Friends · My Club · Everyone: "Friends: people you follow who follow you back."

## 2. Follow back

1. Piero follows Rower B back (on a private account, Rower B accepts first).
- [ ] Rower B pulls the Feed → **Following** to refresh: both of Piero's posts are there, and Rower B can comment and react.
2. Piero unfollows Rower B.
- [ ] Rower B refreshes: the posts have gone. Commenting on one already open says "Only this rower's friends (you follow each other) and clubmates can comment."

## 3. Clubmates unchanged

- [ ] A clubmate of Piero's who doesn't follow him still sees his **My Club** and **Everyone** posts, and not his **Friends** ones unless they follow each other.

## 4. Unchanged elsewhere

- [ ] Rower B (one-way) still sees Piero's profile stats and PBs as before, and Piero on Rankings → Following.
- [ ] A one-way follower gets **no** PB alert for Piero's new PB; a friend does.

# Clubs — setup and test checklist

Decision 25 in `docs/design/v2-decisions.md`. Run against the **staging** Supabase project
(Rowing-Pals-Dev). Tick each box; anything that doesn't match "Expect" is a bug — note the step.

## Cast

- **A** — you, on your phone. Becomes owner of UEA Boat Club in step 3.
- **B** — your second test account, on a simulator (see `phase-e-private-accounts.md` →
  "Set up B on a second simulator"). Starts as a member of UEA Boat Club.

## Part 1 — One-time setup

### 1. Run the clubs migration
1. **supabase.com** → **Rowing-Pals-Dev** → **SQL Editor** → **+ New query**.
2. Open `docs/migrations/2026-09-30-clubs.sql` in TextEdit, **Cmd + A**, **Cmd + C**, paste, **Run**.
3. Expect: **Success. No rows returned.**

### 2. Add the club directory
1. **+ New query**, then the same with `docs/migrations/2026-09-30-club-directory.sql`.
2. Expect: **Success. No rows returned.**
3. Check: run `select count(*) from clubs;` — expect **303** (302 new + UEA Boat Club), or a
   little more if a placeholder club still had members and was kept.

### 3. Make yourself owner of UEA Boat Club
Run this, with the email you sign in to the app with:
```sql
do $$
declare v_user uuid; v_club uuid;
begin
  select id into v_user from auth.users where email = 'YOUR-EMAIL';
  select id into v_club from clubs where lower(name) = 'uea boat club';
  if v_user is null then raise exception 'No account with that email'; end if;
  perform set_config('rp.club_change', 'on', true);
  update profiles set club_id = v_club, club_role = 'owner' where id = v_user;
end $$;
```
Expect: **Success**.

### 4. The guard works
This tries to promote one member by writing their profile directly. The last line always
undoes it, so nothing changes whatever happens:
```sql
do $$ begin
  update profiles set club_role = 'admin'
  where id = (select id from profiles where club_role = 'member' limit 1);
  raise exception 'GUARD FAILED (nothing was saved)';
end $$;
```
- [ ] Expect: **ERROR: Club membership changes go through the app**. (If you see "GUARD FAILED",
      the guard isn't working — tell Claude.)

### 4b. Run the follow-up migration (decision 26)
**+ New query** → paste `docs/migrations/2026-10-04-club-updates.sql` → **Run**. Expect **Success**.
(If it notes "No notifications table", run `2026-09-26-notifications.sql` first, then this again.)

## Part 2 — In the app (build from branch `t28-clubs`)

### 5. Owner view (A)
- [ ] **Profile** → scroll to **Club** → button reads **Manage your club**. Tap it.
      Expect: "YOU ARE THE OWNER", UEA Boat Club, tags (Open membership · University crew ·
      Norwich), Edit club, Join requests · 0, Invite, Members (you + B), Ownership.
- [ ] **Edit club** → set **Who can join?** to **Request approval**, add a description, **Save
      changes**. Expect: the summary shows it.

### 6. Request and approve (B, then A)
- [ ] **B**: Profile → **Your club** → **Continue without a club** → **Leave**. Expect "No club yet".
- [ ] **B**: **Find a club to join** → search "UEA" → the row reads "… · Approval required";
      the button **Request to join UEA Boat Club** → tap it → it turns **Requested** (no level step).
- [ ] **B**: Profile shows **Join request pending · UEA Boat Club**; Your crew shows it with Cancel.
- [ ] **A**: Manage club → **Join requests · 1** → **Accept**. Expect B under Members.

### 7. Roles
- [ ] **A**: Members → B → **Manage** → **Admin**. **B** (pull to refresh Profile): button reads
      **Manage your club**; B sees requests and Invite, **no Edit club**, and Manage only on members.
- [ ] **A**: make B **Co-owner**. **B**: now sees **Edit club**, and can make others member/admin but
      not co-owner.
- [ ] **A**: set B back to **Member**.

### 8. Invitations and the code
- [ ] **A**: Edit club → **Invitation only**. **B** leaves (Your crew → Continue without a club).
- [ ] **B**: Find a club to join → UEA row reads "Invitation only"; the button can't be pressed.
- [ ] **A**: Manage club → **Invite code** — note it (or **Share** it to yourself).
- [ ] **B**: **Have an invite code?** → enter it → **Join**. Expect B is in UEA Boat Club straight away.
- [ ] **B** leaves again. **A**: **Invite a rower** → search B → **Invite** (turns **Invited**).
- [ ] **B**: Your crew → **Invitations** → UEA Boat Club → **Join**. Expect B is back in.
- [ ] **A**: **New** code → the old code no longer works.

### 9. Removing, and the owner's limits
- [ ] **A**: Members → B → Manage → **Remove from club** → confirm. **B**: no club.
- [ ] **A**: Your crew → **Continue without a club** → Leave. Expect the message **"You own your
      club. Hand it over to another member or delete it first."**

### 10. Hand over and delete (on a throwaway club)
- [ ] **B**: Create a club "TEST Club" (Anyone can join). Expect B is its owner (Manage your club).
- [ ] **A**: Find a club to join → TEST Club → expect the owner message (you own UEA).
- [ ] **B**: Manage club → **Delete club** → confirm. Expect B has no club; "TEST Club" is gone from search.
- [ ] Only if you want to test handing over on UEA: A → **Hand over ownership** → B → A becomes
      co-owner, B owner; then B hands it back the same way.

### 11. Onboarding with the new rules (new account)
- [ ] Sign up a new test account → Find your club: rows show the join rule; an approval club
      sends a request and finishes onboarding without a club; **Have an invite code?** works here too.

### 12. Your notes of 2026-10-04 (decision 26)
- [ ] **In a club**, Your crew shows the club card, **every member** (tap one → their profile) and
      only **Leave club** — no Find/Create buttons. An owner sees a line pointing to Manage club.
- [ ] **B** (no club) asks to join an approval club from Find a club: tapping **Request to join** — no level step — the page
      stays, the button reads **Requested** (greyed) and a card says "Request sent" with **Refresh**.
- [ ] **A** accepts, with B still on that page. Expect B's page to close by itself back to where B
      started (Profile), now in the club — no need to leave and come back.
- [ ] Repeat, but **A declines**. Expect B to see **"You weren't accepted to <club>"**, and the
      button **Request again**.
- [ ] **A** invites B. Expect B's Profile → Club to show "<club> invited you to join · View", and
      (once push is switched on) an alert that opens Your crew.
- [ ] **B** declines. Expect A's Manage club → Invited to show B as **"Declined the invitation"**,
      with **Invite again** and **Clear** — without A leaving the page.

## Cleanup
Set UEA Boat Club back to how you want it (Edit club), and put B back in it if you like.

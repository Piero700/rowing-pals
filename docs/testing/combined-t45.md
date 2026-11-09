# Combined test build (branch `t45-combined-test`): phone test checklist

Everything not yet on `main`, in one build, so you can test it together:

| What | Decisions | Detailed checklist |
|---|---|---|
| Grouped rows and no gradients across the app; Feed corners at 18 pt | 99, 100, 101 | `docs/testing/grouped-rows-everywhere.md` |
| Helper text, sign-in layout, open clubs and verification, optional selfie | 98 | `docs/testing/clubs-guidance-selfie.md` |
| Monitor and second photo one at a time | 103 | `docs/testing/one-at-a-time-photos.md` (skip its section 0; use section 0 below) |
| Privacy Policy and Terms wording, Contact us email, delete account removes every photo | 102 | Section 3 below |
| Website (Privacy, Terms, Support pages) and App Store artwork | 100 | Section 4 below (on the Mac, not the phone) |

Work through the detailed checklists in the order above, then sections 3 and 4 here.

## 0. Put the build on your iPhone
1. Plug in your iPhone and unlock it.
2. In Xcode, click **File › Open**, go to the `Rowing Pals` folder, click `Rowing Pals.xcodeproj`, then click **Open**.
3. Check the branch: at the top left of the Xcode window, next to the project name, it should say **t45-combined-test**.
4. At the top of the Xcode window, click the device name and choose your iPhone.
5. Click the **▶** (Run) button. The app opens on your phone after a minute or so.

## 1. Database changes (staging, only if not run before)
In Supabase (staging project) → **SQL Editor** → **New query**, paste each file's contents, click **Run**:
1. `docs/migrations/2026-11-05-delete-all-clubs.sql` (optional, and **only** if you want every club cleared so real owners can pick names)
2. `docs/migrations/2026-11-05-clubs-open-and-verified.sql`

## 2. Deploy the new delete-account function (staging)
**Done 9 Nov 2026:** the new delete-account code is deployed to staging (version 5). Nothing to do here. If it ever
needs redeploying, run this in Terminal in the `Rowing Pals` folder:

```
supabase functions deploy delete-account
```

## 3. Legal wording, Contact us and delete account (Piero, then a throwaway account)
1. **Settings → Help → Privacy Policy**.
   - [ ] It mentions **Friends** (posts are seen by people you both follow), Apple and Google sign-in, notepad scores, attendance and boats.
   - [ ] It does **not** claim photos are screened for objectionable content.
2. **Settings → Help → Terms of Service**.
   - [ ] It still has the zero-tolerance section, and nothing in it reads wrongly for the app as it is now.
3. **Settings → Contact us**.
   - [ ] Mail opens addressed to **support@rowingpals.com** (not `.app`). Send it, and check it arrives in your Outlook.
4. **Delete account** (only after section 2). Use a **new throwaway account**, never Piero or a test account you need.
   1. Sign up, add a profile picture, and post a session with a selfie (and a second photo if you like).
   2. **Settings → Delete account**, then confirm.
   - [ ] You land back on the sign-in screen.
   - [ ] In Supabase → **Storage**, the throwaway's photos are gone from the `monitors` and `selfies` buckets and its profile picture is gone too.
   - [ ] Signing in with the throwaway's email and password no longer works.

## 4. Website and App Store art (on the Mac)
1. The site's links start with `/`, so they only work from a web server, not by double-clicking `index.html`.
   Open **Terminal**, then run this in the `Rowing Pals` folder:
   ```
   python3 -m http.server 8765 --directory marketing/website
   ```
   In Safari, go to **http://localhost:8765**. When you're done, press **Control-C** in Terminal to stop it.
   - [ ] The footer links to **Privacy**, **Terms** and **Support**, and each page opens and reads correctly.
   - [ ] Support shows **support@rowingpals.com**.
   - [ ] No prices anywhere.
2. Open the folder `marketing/app-store/export/`.
   - [ ] Ten screenshots (01 to 10), solid colours (no gradients), no captions cut off.

## Built beyond the brief
Nothing new in this combined build: it only merges the five branches above. The one hand-made change was
the decisions table, where 102 and 103 were each added by a different branch; both rows are kept, in order.

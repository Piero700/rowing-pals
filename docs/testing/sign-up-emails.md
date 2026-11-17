# Sign-up and password emails: setup and test

Why no sign-up email arrives (found 17 Nov 2026): on the **staging** Supabase project, **Confirm
email is turned off**. Every new account is confirmed the moment it's made (`email_confirmed_at` is
the same instant as `created_at`, and `confirmation_sent_at` is empty), so Supabase never sends the
email at all. The app copes either way: with it off you go straight in; with it on you're asked for
the code from the email (decision 66).

Mail itself is already set up: Supabase sends through **Resend** (Authentication → Emails → SMTP
Settings: custom SMTP on, host `smtp.resend.com`, port `465`, username `resend`, the password is the
Resend API key, sender `noreply@rowingpals.com`, name "Rowing Pals"). Those settings are right.

Do this on **staging** first, and the same on **production** before launch.

## 1. Check the sending domain in Resend

Resend only sends from `noreply@rowingpals.com` once rowingpals.com is verified there.

1. Go to **resend.com** → sign in → **Domains** in the left bar.
   - [ ] **rowingpals.com** shows **Verified** (green).
2. If it says **Pending** or **Failed**, click it: it lists DNS records (usually a TXT for `resend._domainkey`,
   an MX and a TXT for `send`). Add each one in **godaddy.com → My Products → rowingpals.com → DNS →
   Add New Record**, exactly as shown, without removing the Microsoft 365 records. Then click **Verify DNS
   Records** in Resend (it can take up to an hour).
3. **API Keys**: the key used as Supabase's SMTP password must have **Sending access** (or Full access).

## 2. Put in the new email designs

The emails now look like rowingpals.com (solid colours, 12 px corners, same fonts and blues).

1. Supabase → **staging** project → **Authentication** → **Emails** → **Templates** → **Confirm signup**.
2. **Subject:** `Your Rowing Pals code: {{ .Token }}`
3. In Finder open `Rowing Pals/marketing/emails/confirm-account.html` in TextEdit (right-click →
   Open With → TextEdit; if it shows the design instead of code, TextEdit → Settings → Open and Save →
   tick **Display HTML files as HTML code instead of formatted text**, then reopen). Select everything
   (**⌘A**), copy (**⌘C**).
4. In Supabase, switch the message body to the **Source** (or **HTML**) view, select everything, paste
   (**⌘V**) → **Save**.
5. Do the same for **Reset password** with subject `Reset your Rowing Pals password` and the file
   `marketing/emails/reset-password.html`.

The logo in the emails loads from rowingpals.com, so it only shows once the website is uploaded
(`docs/testing/minimum-age.md`, section 8).

## 3. Turn on Confirm email and test

1. **Authentication** → **Sign In / Providers** → **Email** → turn on **Confirm email** → **Save**.
2. In the app: sign out → **New here? Create an account** → sign up with an email address you can open
   that hasn't been used before.
   - [ ] The app asks for a code.
   - [ ] An email arrives within a minute (check junk too), looking like the website, with the code.
   - [ ] Typing the code signs you in.
3. Sign out → **Forgot password?** → your email → **Send code**.
   - [ ] The reset email arrives in the new design and its code works.
4. If no email comes:
   - Supabase → **Authentication** → **Logs** (or **Logs & Analytics → Auth**): look for a red line
     about SMTP.
   - Resend → **Emails** (or **Logs**): see whether the email reached Resend and whether it bounced.
   - Send me a screenshot of either.

# Sign-up and password emails: setup and test

Why no sign-up email arrives (found 17 Nov 2026): on the **staging** Supabase project, **Confirm
email is turned off**. Every new account is confirmed the moment it's made (`email_confirmed_at` is
the same instant as `created_at`, and `confirmation_sent_at` is empty), so Supabase never sends the
email at all. The app copes either way: with it off you go straight in; with it on you're asked for
the code from the email (decision 66).

Turning it on only works once Supabase can actually send mail to anyone. Its built-in mailer only
delivers to your own team's addresses and a couple of times an hour, so first give it a real mail
server (section 2). Do sections 1–5 on **staging** first; repeat on **production** before launch.

## 1. Check what's set now

1. Go to **supabase.com** → sign in → open the **staging** project.
2. Left bar: **Authentication** → **Sign In / Providers** → open **Email**.
   - Note whether **Confirm email** is on or off (it's off on staging today).
3. Left bar: **Authentication** → **Emails** → **SMTP Settings**.
   - Note whether **Enable Custom SMTP** is on.

## 2. Let Supabase send from noreply@rowingpals.com (Microsoft 365)

**First, allow the mailbox to send by SMTP** (Microsoft turns this off by default):

1. Go to **admin.microsoft.com** and sign in with your Microsoft 365 admin account (through
   GoDaddy: **godaddy.com → My Products → Microsoft 365 → Admin** if it asks).
2. **Users** → **Active users** → click **noreply@rowingpals.com**.
3. **Mail** tab → **Manage email apps** → tick **Authenticated SMTP** → **Save changes**.

**Then give Supabase the server:**

4. Back in Supabase: **Authentication** → **Emails** → **SMTP Settings** → turn on **Enable Custom SMTP**.
5. Fill in:
   - **Sender email:** `noreply@rowingpals.com`
   - **Sender name:** `Rowing Pals`
   - **Host:** `smtp.office365.com`
   - **Port:** `587`
   - **Username:** `noreply@rowingpals.com`
   - **Password:** that mailbox's password (type it yourself; it's never put in the app or the code)
   - **Minimum interval between emails:** leave as it is
6. **Save changes**.

If Microsoft refuses (the test in section 5 shows an error mentioning "authentication unsuccessful"
or "SmtpClientAuthentication is disabled"), GoDaddy's Microsoft 365 often blocks SMTP sign-in
completely. Then the simplest fix is a sending service such as **Resend** or **Postmark** (both have a
free tier): sign up, add the DNS records they show you in **GoDaddy → My Products → rowingpals.com →
DNS** (don't remove the Microsoft 365 records), and put their SMTP host, port, username and password in
step 5 instead.

## 3. Raise the email limit

1. **Authentication** → **Rate Limits**.
2. **Rate limit for sending emails:** set to `30` per hour (only possible once custom SMTP is on).
3. **Save changes**.

## 4. Put in the new email designs

The emails now look like rowingpals.com (solid colours, 12 px corners, same fonts and blues).

1. **Authentication** → **Emails** → **Templates** → **Confirm signup**.
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

## 5. Turn on Confirm email and test

1. **Authentication** → **Sign In / Providers** → **Email** → turn on **Confirm email** → **Save**.
2. In the app: sign out → **New here? Create an account** → sign up with an email address you can open
   that hasn't been used before.
   - [ ] The app asks for a code.
   - [ ] An email arrives within a minute (check junk too), looking like the website, with the code.
   - [ ] Typing the code signs you in.
3. Sign out → **Forgot password?** → your email → **Send code**.
   - [ ] The reset email arrives in the new design and its code works.
4. If no email comes: **Authentication** → **Logs** (or **Logs & Analytics → Auth**) and look for a
   red line about SMTP; send me a screenshot of it.

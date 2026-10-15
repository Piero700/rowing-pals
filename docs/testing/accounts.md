# Accounts: email confirmation, Forgot password, Apple and Google — setup and test (decision 66, 2026-10-15)

The app side is built. Each sign-in method also needs switching on in places only you can reach.
Do the **staging** project first; repeat for production before launch.

## A. Email confirmation and codes (Supabase — about 5 minutes)
1. Supabase dashboard → **staging** project → **Authentication** (left bar) → **Sign In / Providers**.
2. Under **Email**: make sure **Enable email provider** is on and turn **Confirm email** **on**. Click **Save**.
3. **Authentication** → **Emails** (or **Email Templates**) → **Confirm signup**. Replace the body with:
   ```
   <h2>Confirm your email</h2>
   <p>Your Rowing Pals code is:</p>
   <p style="font-size:28px;font-weight:bold;letter-spacing:4px">{{ .Token }}</p>
   <p>Enter it in the app. It works for an hour.</p>
   ```
   Subject: `Your Rowing Pals code`. Click **Save**.
4. Same page → **Reset password** (sometimes "Reset Password"). Replace the body with:
   ```
   <h2>Reset your password</h2>
   <p>Your Rowing Pals code is:</p>
   <p style="font-size:28px;font-weight:bold;letter-spacing:4px">{{ .Token }}</p>
   <p>Enter it in the app with your new password. If you didn't ask for this, ignore this email.</p>
   ```
   Subject: `Reset your Rowing Pals password`. Click **Save**.
5. Note: Supabase's built-in email sends only a few emails an hour and only to your team's
   addresses until you add your own email service (**Authentication → Emails → SMTP Settings**,
   e.g. Resend or Postmark). Fine for testing; needed before launch.

## B. Sign in with Apple (about 10 minutes)
1. **Xcode**: open the project, click the **Rowing Pals** target → **Signing & Capabilities**. You should
   now see **Sign in with Apple** listed (the app asks for it). If Xcode shows a red signing error,
   click **Try Again** — with automatic signing it switches it on for the app's ID itself.
2. **Supabase** → staging → **Authentication** → **Sign In / Providers** → **Apple** → turn it **on**.
3. In **Client IDs** enter: `rowingpals.Rowing-Pals.dev,rowingpals.Rowing-Pals.beta,rowingpals.Rowing-Pals`
   (the app's IDs for Debug, Staging and Release). Leave the secret key fields empty — they're only for
   signing in on the web. Click **Save**.

## C. Continue with Google (about 15 minutes)
1. Go to https://console.cloud.google.com → top bar project picker → **New project** → name it
   `Rowing Pals` → **Create**, and select it.
2. Left menu → **APIs & Services** → **OAuth consent screen** → **Get started**: app name `Rowing Pals`,
   your support email, audience **External**, your contact email → **Create**.
3. **APIs & Services** → **Credentials** → **+ Create credentials** → **OAuth client ID** →
   Application type **Web application**, name `Supabase`.
4. Under **Authorised redirect URIs** click **+ Add URI** and paste the **Callback URL** shown on
   Supabase's Google provider page (step 5 — it looks like
   `https://<your-staging-ref>.supabase.co/auth/v1/callback`). Click **Create**, and copy the
   **Client ID** and **Client secret**.
5. **Supabase** → staging → **Authentication** → **Sign In / Providers** → **Google** → turn it **on**,
   paste the Client ID and Client secret → **Save**.
6. **Supabase** → **Authentication** → **URL Configuration** → **Redirect URLs** → **Add URL** →
   `rowingpals://auth-callback` → **Save**.
7. While the Google app is in "Testing", only test users can sign in: **OAuth consent screen** →
   **Audience** → **+ Add users** → add your Google address. (Publish it before launch.)

## D. Test on your phone (Cmd+R with the RP Dev scheme)
- [ ] **Sign up** with a new email: the app shows **Check your email** and a code box. The email has a code;
      type it → **Confirm email** → you're into club onboarding.
- [ ] A wrong code: "That code has expired or isn't right…". **Resend code** sends another.
- [ ] Sign up, close the app before entering the code, then **Sign in**: it says to confirm first and
      sends a fresh code.
- [ ] **Sign in → Forgot password?** → your email → **Send code** → code + new password →
      **Set new password**: you're signed in. Sign out and in with the new password.
- [ ] **Sign in with Apple**: Apple's sheet → Continue → into onboarding (name from Apple). Signing in again
      later goes straight in.
- [ ] **Continue with Google**: Google's page in a sheet → choose your account → back in the app, signed in.
- [ ] Closing the Apple or Google sheet without signing in shows no error.
- [ ] Moving between Sign in, Create account and Forgot password slides like a pushed screen.

## Added beyond what you asked — check these
- [ ] Codes typed in the app rather than tapping links in the email.
- [ ] "By continuing with Apple or Google you agree to the Terms of Service" (Apple/Google skip the tick box).
- [ ] Plain-English error messages (wrong password, expired code, email already used, too many emails).
- [ ] Signing in unconfirmed sends a fresh code automatically.
- [ ] The password field offers iOS's strong-password suggestion on sign-up, and codes from Mail can
      be auto-filled above the keyboard.

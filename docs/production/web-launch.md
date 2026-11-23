# Putting the rower web page online (decision 110)

Written 2026-11-19. The page lives in `web/` (React, Vite, TypeScript) and is built to static files.
Do sections 1 to 3 now for the **staging** copy (needed for `docs/testing/whatsapp-share-and-web.md`).
Do section 4 only at App Store launch, after `docs/production/app-store-launch.md`.
No keys or project references go in this file: take them from `Staging.xcconfig` and the Supabase dashboard.
**(Claude)** marks a step you tell Claude to do.

> **Changed 23 Nov 2026: rowingpals.com is the test site.** GitHub was connected to the existing rowingpals.com
> Netlify site (`earnest-lokum-3b10a8`), not a new staging site, and the user chose to keep it that way. Until
> production Supabase exists, rowingpals.com builds branch `t48-whatsapp-web` in staging mode with the **staging**
> Supabase variables, so `rowingpals.com/go` uses staging data and every push to that branch goes live. So, in place of
> sections 2 and 3: add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` (staging) to that site and redeploy;
> `WEB_ORIGINS` is not needed (rowingpals.com is allowed in the code); add `https://rowingpals.com/go/` to staging
> Supabase's Redirect URLs and `https://rowingpals.com` to the Google Web client's Authorised JavaScript origins.
> After the branch is merged, set the site's branch to `main`. At launch (section 4), change the same site's variables to
> production and add `WEB_MODE` = `production`, instead of making a new site.

## 1. Deploy the two Edge Functions to staging
They gained CORS headers so a browser may call them.
1. **Done 20 Nov 2026:** both are deployed to staging (`username-auth` version 2, `delete-account` version 6,
   the sign-in token check left on as before). Claude checked them: an OPTIONS call from `http://localhost:5173` or
   `https://rowingpals.com` gets `200` with that address echoed back, another address gets no permission line, a
   wrong username sign-in from the web page shows "That username and password don’t match.", and a call without an
   Origin (as the iPhone app makes) still works. If they ever need redeploying, tell Claude "deploy the web functions
   to staging", or run `supabase functions deploy username-auth` and `supabase functions deploy delete-account` in
   Terminal in the `Rowing Pals` folder.
2. **Still to do, after section 2:** set the allowed web address for the staging site (`localhost:5173`,
   `rowingpals.com` and `www.rowingpals.com` are already allowed in the code). Go to https://supabase.com/dashboard → open the **staging** project →
   **Edge Functions** (left bar) → **Secrets** (or **Manage secrets**) → **Add new secret**. Name:
   `WEB_ORIGINS`. Value: the staging web address from section 2 (for example `https://something.netlify.app`, with no
   slash at the end; separate several with commas). Click **Save**. If you haven't made the site yet, do section 2
   first, then come back to this step.
3. Check it. In the Terminal app run (put the staging ref in place of `<staging ref>`):
   `curl -i -X OPTIONS -H "Origin: http://localhost:5173" -H "Access-Control-Request-Method: POST" https://<staging ref>.supabase.co/functions/v1/username-auth`
   - [ ] The first line says `200` and there is a line `access-control-allow-origin: http://localhost:5173`.
   - [ ] The same with `delete-account` instead of `username-auth` gives the same.
   - [ ] Repeat with `-H "Origin: <your staging web address>"`: it echoes that address back.
4. In the iPhone app on staging, sign in with your username. It should still work.

## 2. Make the staging Netlify site
1. Go to https://app.netlify.com and sign in. Click **Add new site** → **Import an existing project**.
2. Choose **GitHub** and pick the Rowing Pals repository. Branch to deploy: `t48-whatsapp-web` for now
   (change it to `main` after the branch is merged: **Site configuration** → **Build & deploy** → **Branches**).
3. Fill in the build settings:
   - **Base directory**: `web`
   - **Build command**: `npm run build:site` (the same as `web/netlify.toml`, which wins if the two differ)
   - **Publish directory**: `web/dist`
   The build puts the page in `web/dist/go` and copies the website (`marketing/website`) beside it in `web/dist`, so the
   staging site also shows the website at its root. With no `WEB_MODE` variable it builds in staging mode.
4. Click **Add environment variables** (or after making the site: **Site configuration** → **Environment variables** → **Add a variable**) and add:
   - `VITE_SUPABASE_URL` = the staging Project URL (copy it from `Staging.xcconfig`; if it shows with a stray `$()` in the file, use the plain https address).
   - `VITE_SUPABASE_ANON_KEY` = the staging anon key (copy it from `Staging.xcconfig`).
   Use staging values only. Never put the production ones here. Don't add `WEB_MODE` on this site.
5. Click **Deploy**. When it says **Published**, copy the site address at the top (ending `.netlify.app`).
   Optionally rename it: **Site configuration** → **Change site name**.
6. Open that address followed by `/go/`.
   - [ ] You see the sign-in screen. Opening `/go/anything` shows it too (the rewrite in `web/netlify.toml`).
7. Go back to section 1 step 2 and set `WEB_ORIGINS` to this address.

## 3. Allow the staging web address to sign in
1. Supabase dashboard → the **staging** project → **Authentication** → **URL Configuration**.
2. Under **Redirect URLs** click **Add URL** and add each of these, saving each time:
   - `<staging web address>/go/`
   - `http://localhost:5173/go/`
3. Click **Save changes**. Leave **Site URL** as it is.
4. Google sign-in: Supabase → **Authentication** → **Providers** → **Google**. The redirect Supabase shows
   (`https://<staging ref>.supabase.co/auth/v1/callback`) is the same one the app uses, so Google Cloud needs nothing
   new for it. In https://console.cloud.google.com → **APIs & Services** → **Credentials** → the **Web** OAuth client →
   **Authorised JavaScript origins** → **Add URI** → the staging web address. Click **Save**.
   - [ ] On the web page tap **Continue with Google** and sign in: you come back to the staging page signed in.

## 4. At App Store launch: production
Only after the production project exists (`docs/production/app-store-launch.md`).
1. **(Claude)** Tell Claude "deploy the web functions to production". Claude deploys `username-auth` and
   `delete-account` to the production project (they may already be there from App Store step 2.4: deploy again so they have the CORS change).
2. Production Supabase → **Edge Functions** → **Secrets** → **Add new secret**: `WEB_ORIGINS` is not needed for
   `https://rowingpals.com` (always allowed). Leave it empty unless you add another address.
3. Production Supabase → **Authentication** → **URL Configuration** → **Redirect URLs** → **Add URL**:
   `https://rowingpals.com/go/`. Click **Save changes**.
4. Google Cloud → **Credentials** → the **Web** OAuth client → **Authorised JavaScript origins** → **Add URI**:
   `https://rowingpals.com`. Click **Save**.
5. Make the production Netlify site. One site holds both the website and `/go`: `npm run build:site` builds the page into
   `web/dist/go` and copies `marketing/website/` (the home page, `/privacy`, `/terms`, `/support` and `assets/`) into
   `web/dist` beside it; Netlify publishes `web/dist`. Nothing needs adding by hand.
   1. https://app.netlify.com → **Add new site** → **Import an existing project** → **GitHub** → the Rowing Pals repository.
      Branch to deploy: `main`.
   2. **Base directory** `web`, **Build command** `npm run build:site`, **Publish directory** `web/dist`.
   3. **Add environment variables**:
      - `WEB_MODE` = `production`
      - `VITE_SUPABASE_URL` = the production Project URL (Supabase → the **production** project → **Project Settings** → **API**).
      - `VITE_SUPABASE_ANON_KEY` = the production anon key (same page).
   4. Click **Deploy**. When it says **Published**, open the `.netlify.app` address it shows, add `/go/`, and sign in with a
      real account: it must be a production account (a staging-only account must fail). The page must never talk to staging.
   5. If rowingpals.com is already served by another Netlify site (the website on its own), delete that site's domain first:
      that site → **Domain management** → the three dots beside `rowingpals.com` → **Remove domain**.
6. Point rowingpals.com at the new site: Netlify → the new site → **Domain management** → **Add a domain** →
   `rowingpals.com` → **Verify** → **Add domain**, and follow the DNS steps it shows. Add `www.rowingpals.com` too when it
   offers (the Edge Functions allow both addresses).
7. Check it, on a phone that is not on your Wi-Fi:
   - [ ] https://rowingpals.com/go/ shows the sign-in screen, and https://rowingpals.com/go/anything does too.
   - [ ] https://rowingpals.com, /privacy, /terms and /support still load.
   - [ ] A web account joins a real club and its answers show in the coach's Who's available on the iPhone app.

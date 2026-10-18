// username-auth
//
// Decision 85: signing in, and resetting a password, with a username instead of an email. The
// username is turned into the account's email here, on the server, with the service-role key —
// the app never sees anyone's email, so a username (which is shown as @username) can't be used to
// find an email address.
//
//   { action: "sign-in",    username, password }           → { access_token, refresh_token }
//   { action: "send-reset", username }                     → { ok: true }  (the same either way)
//   { action: "reset",      username, code, newPassword }  → { access_token, refresh_token }
//   errors                                                 → { error, message } with a 4xx status
//
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are injected automatically into
// every Edge Function. The rower's own address is passed on (X-Forwarded-For) so Supabase's sign-in
// and email rate limits apply per person, not to this function as a whole.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const USERNAME = /^[a-z0-9_]([a-z0-9._]{1,18})[a-z0-9_]$/
const MIN_PASSWORD = 6

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })

const wrongPassword = () =>
  json({ error: "invalid_credentials", message: "That username and password don’t match." }, 400)
const badCode = () =>
  json({ error: "otp_expired", message: "That code has expired or isn’t right. Tap Resend code for a new one." }, 400)

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method", message: "Use POST." }, 405)
  const body = await req.json().catch(() => ({})) as Record<string, unknown>
  const action = String(body.action ?? "")
  const username = String(body.username ?? "").trim().toLowerCase().replace(/^@/, "")

  const url = Deno.env.get("SUPABASE_URL")!
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  const forwarded = req.headers.get("x-forwarded-for")
  const passOn = forwarded ? { "X-Forwarded-For": forwarded } : {}

  const admin = createClient(url, serviceKey, { auth: { persistSession: false } })
  const auth = createClient(url, anonKey, { auth: { persistSession: false }, global: { headers: passOn } }).auth

  /** The account's email for a username, or null. */
  async function emailFor(name: string): Promise<string | null> {
    if (!USERNAME.test(name)) return null
    const { data: row } = await admin.from("profiles").select("id").eq("username", name).maybeSingle()
    if (!row) return null
    const { data } = await admin.auth.admin.getUserById(row.id as string)
    return data?.user?.email ?? null
  }

  switch (action) {
    case "sign-in": {
      const password = String(body.password ?? "")
      const email = await emailFor(username)
      if (!email || !password) return wrongPassword()
      const { data, error } = await auth.signInWithPassword({ email, password })
      if (error?.code === "email_not_confirmed") {
        return json({ error: "email_not_confirmed", message: "Confirm your email first: sign in with your email to get a new code." }, 400)
      }
      if (error?.status === 429) {
        return json({ error: "over_request_rate_limit", message: "Too many tries just now. Wait a minute, then try again." }, 429)
      }
      if (error || !data.session) return wrongPassword()
      return json({ access_token: data.session.access_token, refresh_token: data.session.refresh_token })
    }

    case "send-reset": {
      const email = await emailFor(username)
      if (email) {
        const { error } = await auth.resetPasswordForEmail(email)
        if (error?.status === 429) {
          return json({ error: "over_email_send_rate_limit", message: "Too many emails just now. Wait a minute, then try again." }, 429)
        }
      }
      // The same answer whether or not the username exists.
      return json({ ok: true })
    }

    case "reset": {
      const code = String(body.code ?? "").replace(/\D/g, "")
      const newPassword = String(body.newPassword ?? "")
      if (newPassword.length < MIN_PASSWORD) {
        return json({ error: "weak_password", message: `Choose a longer password: at least ${MIN_PASSWORD} characters.` }, 400)
      }
      const email = await emailFor(username)
      if (!email || !code) return badCode()
      const { data, error } = await auth.verifyOtp({ email, token: code, type: "recovery" })
      if (error || !data.session || !data.user) return badCode()
      const { error: updateError } = await admin.auth.admin.updateUserById(data.user.id, { password: newPassword })
      if (updateError) return json({ error: "update_failed", message: "Couldn’t set the new password. Please try again." }, 400)
      return json({ access_token: data.session.access_token, refresh_token: data.session.refresh_token })
    }

    default:
      return json({ error: "action", message: "Unknown action." }, 400)
  }
})

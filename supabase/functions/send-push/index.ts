// send-push
//
// Delivers one row of the `notifications` outbox (docs/migrations/2026-09-26-notifications.sql)
// to every phone its recipient is signed in on, through Apple Push Notification service.
// Called by the database webhook on `notifications` INSERT (docs/testing/notifications.md).
//
// Only the row's id is taken from the request. Everything else is read back from the
// database, and the row is claimed with one atomic update, so a call can do nothing but
// deliver a real, unsent notification to its rightful recipient, once.
//
// Secrets (set with `supabase secrets set`, never committed): APNS_KEY_ID, APNS_TEAM_ID,
// APNS_PRIVATE_KEY (the whole .p8 file). SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are
// injected automatically.

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2"

type Kind =
  | "comment" | "reply" | "pb" | "club_post" | "club_invite" | "new_workout"
  | "new_practice" | "practice_changed" | "practice_cancelled" | "practice_reminder" | "new_event"
  | "boat_seat" | "announcement"

interface NotificationRow {
  id: string
  recipient_id: string
  actor_id: string
  kind: Kind
  // Empty for a club invitation (docs/migrations/2026-10-04-club-updates.sql).
  session_id: string | null
  comment_id: string | null
  club_id?: string | null
  // A coach's set workout (docs/migrations/2026-10-05-coaching.sql, decision 39).
  workout_id?: string | null
  // A practice, or a race or event (docs/migrations/2026-10-16-calendar.sql, decision 68).
  practice_id?: string | null
  event_id?: string | null
  // A boat in a water session (docs/migrations/2026-10-16-boats.sql, decision 67).
  boat_id?: string | null
  // A coach's announcement (docs/migrations/2026-10-17-rigging-and-announcements.sql, decision 75).
  announcement_id?: string | null
}

interface DeviceToken {
  token: string
  bundle_id: string
  apns_env: "sandbox" | "production" | null
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })

Deno.serve(async (req) => {
  const keyId = Deno.env.get("APNS_KEY_ID")
  const teamId = Deno.env.get("APNS_TEAM_ID")
  const privateKey = Deno.env.get("APNS_PRIVATE_KEY")
  if (!keyId || !teamId || !privateKey) {
    // Left unsent, not claimed: nothing is lost while the Apple key is still being set up.
    return json({ error: "APNs secrets are not set" }, 503)
  }

  let id: string | undefined
  try {
    const payload = await req.json()
    id = payload?.record?.id
  } catch {
    // Falls through to the 400 below.
  }
  if (!id) return json({ error: "Expected a notifications webhook payload" }, 400)

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)

  const { data: claimed, error: claimError } = await admin
    .from("notifications")
    .update({ sent_at: new Date().toISOString() })
    .eq("id", id)
    .is("sent_at", null)
    .select("*")
    .maybeSingle()
  if (claimError) return json({ error: claimError.message }, 500)
  if (!claimed) return json({ skipped: "already sent or not found" })
  const row = claimed as NotificationRow

  const { data: tokens } = await admin
    .from("device_tokens")
    .select("token, bundle_id, apns_env")
    .eq("user_id", row.recipient_id)
  if (!tokens || tokens.length === 0) return json({ delivered: 0, reason: "no devices" })

  const alert = await composeAlert(admin, row)
  if (!alert) return json({ skipped: "post no longer exists" })

  const body = {
    aps: {
      alert,
      "thread-id": row.session_id ?? row.workout_id ?? row.practice_id ?? row.event_id ?? row.boat_id ?? row.announcement_id ?? row.club_id ?? row.id,
      "interruption-level": "active",
      sound: "default",
    },
    // The app opens the post, or Your club for an invitation.
    ...(row.session_id ? { session_id: row.session_id } : {}),
    ...(row.club_id ? { club_id: row.club_id } : {}),
    ...(row.workout_id ? { workout_id: row.workout_id } : {}),
    ...(row.practice_id ? { practice_id: row.practice_id } : {}),
    ...(row.event_id ? { event_id: row.event_id } : {}),
    ...(row.boat_id ? { boat_id: row.boat_id } : {}),
    ...(row.announcement_id ? { announcement_id: row.announcement_id } : {}),
    kind: row.kind,
  }

  const jwt = await providerToken(keyId, teamId, privateKey)
  let delivered = 0
  for (const device of tokens as DeviceToken[]) {
    if (await deliver(admin, jwt, device, body)) delivered++
  }
  return json({ delivered })
})

// MARK: - Alert text

async function composeAlert(admin: SupabaseClient, row: NotificationRow) {
  if (row.kind === "club_invite") {
    const { data: club } = await admin.from("clubs").select("name").eq("id", row.club_id).maybeSingle()
    if (!club) return null
    const actor = await displayName(admin, row.actor_id)
    return { title: club.name as string, body: `${actor} invited you to join. Tap to answer.` }
  }
  if (row.kind === "new_workout") {
    const { data: workout } = await admin
      .from("coach_workouts")
      .select("title, workout_date, start_time")
      .eq("id", row.workout_id)
      .maybeSingle()
    if (!workout) return null
    const coach = await displayName(admin, row.actor_id)
    return {
      title: "New workout from your coach",
      body: `${coach}: ${workout.title} · ${when(workout.workout_date, workout.start_time)}`,
    }
  }
  if (row.kind === "announcement") {
    const { data: announcement } = await admin
      .from("announcements")
      .select("heading, expires_at")
      .eq("id", row.announcement_id)
      .maybeSingle()
    if (!announcement || new Date(announcement.expires_at as string) <= new Date()) return null
    return { title: "New announcement", body: announcement.heading as string }
  }
  if (row.kind === "boat_seat") {
    const { data: boat } = await admin
      .from("session_boats")
      .select("name, boat_type, sent_at, water_sessions(starts_at)")
      .eq("id", row.boat_id)
      .maybeSingle()
    if (!boat || !boat.sent_at) return null
    const { data: seat } = await admin
      .from("session_boat_seats")
      .select("seat")
      .eq("boat_id", row.boat_id)
      .eq("user_id", row.recipient_id)
      .maybeSingle()
    if (!seat) return null
    const session = boat.water_sessions as { starts_at?: string } | null
    if (!session?.starts_at) return null
    const day = new Date(session.starts_at)
      .toLocaleDateString("en-GB", { weekday: "short", timeZone: "Europe/London" })
    return {
      title: "Your boat",
      body: `${day} ${clock(session.starts_at)} · ${seatPhrase(seat.seat as number, boat.boat_type as string)} ${boat.name}`,
    }
  }
  if (row.kind === "new_practice" || row.kind === "practice_changed" || row.kind === "practice_cancelled" ||
      row.kind === "practice_reminder") {
    const { data: practice } = await admin
      .from("practices")
      .select("title, place, starts_at, cancelled, series_id")
      .eq("id", row.practice_id)
      .maybeSingle()
    if (!practice) return null
    const what = (practice.title as string | null) ?? "Practice"
    const where = practice.place ? ` · ${practice.place}` : ""
    if (row.kind === "practice_reminder") {
      if (practice.cancelled) return null
      return { title: "Practice in 2 hours", body: `${what} · ${clock(practice.starts_at)}${where}` }
    }
    const coach = await displayName(admin, row.actor_id)
    if (row.kind === "new_practice") {
      if (practice.cancelled) return null
      const weekly = practice.series_id ? " · every week" : ""
      return { title: "New practice", body: `${coach}: ${what} · ${moment(practice.starts_at)}${where}${weekly}. Tap to say if you can make it.` }
    }
    if (row.kind === "practice_cancelled") {
      return { title: "Practice cancelled", body: `${coach}: ${what} · ${moment(practice.starts_at)} is off.` }
    }
    return { title: "Practice changed", body: `${coach}: ${what} · ${moment(practice.starts_at)}${where}` }
  }
  if (row.kind === "new_event") {
    const { data: event } = await admin
      .from("club_events")
      .select("kind, name, first_day, last_day, place, asks_availability")
      .eq("id", row.event_id)
      .maybeSingle()
    if (!event) return null
    const coach = await displayName(admin, row.actor_id)
    const days = event.first_day === event.last_day
      ? when(event.first_day, null)
      : `${when(event.first_day, null)} – ${when(event.last_day, null)}`
    const where = event.place ? ` · ${event.place}` : ""
    const ask = event.asks_availability ? (event.kind === "race" ? " Can you race? Tap to answer." : " Can you come? Tap to answer.") : ""
    return { title: event.name as string, body: `${coach} added it: ${days}${where}.${ask}` }
  }
  if (!row.session_id) return null

  const { data: session } = await admin
    .from("sessions")
    .select("user_id, type, workout_label, total_distance_m")
    .eq("id", row.session_id)
    .maybeSingle()
  if (!session) return null

  const actor = await displayName(admin, row.actor_id)
  const what = describe(session.workout_label, session.type)

  switch (row.kind) {
    case "comment":
    case "reply": {
      const { data: comment } = row.comment_id
        ? await admin.from("comments").select("body").eq("id", row.comment_id).maybeSingle()
        : { data: null }
      const quote = comment ? `: “${snippet(comment.body)}”` : ""
      if (row.kind === "comment") {
        return { title: actor, body: `Commented on your ${what}${quote}` }
      }
      const whose = session.user_id === row.actor_id
        ? "their"
        : `${await displayName(admin, session.user_id)}’s`
      return { title: actor, body: `Replied on ${whose} ${what}${quote}` }
    }
    case "pb": {
      const test = (session.workout_label ?? "test").replace(/ test$/i, "")
      const result = await leadResult(admin, row.session_id, session.workout_label)
      if (row.recipient_id === row.actor_id) {
        return { title: "New personal best", body: `Your ${test} is now ${result}.` }
      }
      return { title: actor, body: `New ${test} PB: ${result}` }
    }
    case "club_post": {
      const { data: author } = await admin
        .from("profiles")
        .select("clubs(name)")
        .eq("id", row.actor_id)
        .maybeSingle()
      const club = (author?.clubs as { name?: string } | null)?.name ?? "Your club"
      const label = session.workout_label as string | null
      const posted = label && /test$/i.test(label)
        ? `a ${label}`
        : `${metres(session.total_distance_m)} ${label ?? "on the erg"}`
      return { title: club, body: `${actor} posted ${posted}` }
    }
  }
}

async function displayName(admin: SupabaseClient, userId: string) {
  const { data } = await admin.from("profiles").select("display_name").eq("id", userId).maybeSingle()
  return (data?.display_name as string | undefined) ?? "A rower"
}

function describe(label: string | null, type: string) {
  if (label) return label
  return "session"
}

/// "Tue 7 Oct, 06:30" or "Sat 11 Oct" — the workout's own day, written as UK dates.
function when(day: string, time: string | null) {
  const [y, m, d] = day.split("-").map(Number)
  const date = new Date(Date.UTC(y, m - 1, d))
  const text = date.toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short", timeZone: "UTC" })
  return time ? `${text.replace(",", "")}, ${time.slice(0, 5)}` : text.replace(",", "")
}

/// "you’re at stroke in", "you’re in seat 2 in", "you’re coxing": seat 1 is bow, the highest is
/// stroke, 0 the cox (as BoatRules.seatPhrase in the app).
function seatPhrase(seat: number, type: string) {
  const rowers: Record<string, number> = { "1x": 1, "2x": 2, "2-": 2, "4-": 4, "4+": 4, "4x": 4, "8+": 8 }
  const count = rowers[type] ?? 0
  if (seat === 0) return "you’re coxing"
  if (count === 1) return "you’re in"
  if (seat === count) return "you’re at stroke in"
  if (seat === 1) return "you’re at bow in"
  return `you’re in seat ${seat} in`
}

/// "Tue 20 Oct, 06:30": a practice's start, in UK time.
function moment(iso: string) {
  const date = new Date(iso)
  const day = date.toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short", timeZone: "Europe/London" })
  return `${day.replace(",", "")}, ${clock(iso)}`
}

/// "06:30" in UK time.
function clock(iso: string) {
  return new Date(iso).toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit", timeZone: "Europe/London" })
}

function snippet(text: string) {
  const oneLine = text.replace(/\s+/g, " ").trim()
  return oneLine.length > 90 ? `${oneLine.slice(0, 89)}…` : oneLine
}

/// The test's result off the lead piece: distance for a timed test, time otherwise.
async function leadResult(admin: SupabaseClient, sessionId: string, label: string | null) {
  const { data: pieces } = await admin
    .from("segments")
    .select("distance_m, time_ms, is_lead, position")
    .eq("session_id", sessionId)
    .order("position")
  const lead = pieces?.find((p) => p.is_lead) ?? pieces?.[0]
  if (!lead) return "a new best"
  return label && /min test$/i.test(label) ? metres(lead.distance_m) : duration(lead.time_ms)
}

/// "7,460m" — UK copy, grouped thousands, as the app shows it.
function metres(m: number) {
  return `${m.toLocaleString("en-GB")}m`
}

/// Mirrors Int.formattedDurationMs in the app: "M:SS.d" under an hour, "H:MM:SS" beyond.
function duration(ms: number) {
  const tenths = Math.floor(ms / 100)
  const totalSeconds = Math.floor(tenths / 10)
  const seconds = totalSeconds % 60
  const totalMinutes = Math.floor(totalSeconds / 60)
  const minutes = totalMinutes % 60
  const hours = Math.floor(totalMinutes / 60)
  const two = (n: number) => String(n).padStart(2, "0")
  return hours > 0 ? `${hours}:${two(minutes)}:${two(seconds)}` : `${minutes}:${two(seconds)}.${tenths % 10}`
}

// MARK: - APNs

let cachedToken: { jwt: string; issuedAt: number } | null = null

const base64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")

/// Apple's provider token: an ES256 JWT, reused for up to 50 minutes (Apple allows 60).
async function providerToken(keyId: string, teamId: string, pem: string) {
  if (cachedToken && Date.now() - cachedToken.issuedAt < 50 * 60 * 1000) return cachedToken.jwt
  const der = Uint8Array.from(
    atob(pem.replace(/\\n/g, "\n").replace(/-----[^-]+-----/g, "").replace(/\s+/g, "")),
    (c) => c.charCodeAt(0),
  )
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"])
  const encoder = new TextEncoder()
  const header = base64url(encoder.encode(JSON.stringify({ alg: "ES256", kid: keyId })))
  const claims = base64url(encoder.encode(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) })))
  // WebCrypto's ECDSA signature is already the raw r||s form JWS wants.
  const signature = new Uint8Array(
    await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, encoder.encode(`${header}.${claims}`)),
  )
  const jwt = `${header}.${claims}.${base64url(signature)}`
  cachedToken = { jwt, issuedAt: Date.now() }
  return jwt
}

/// Sends to one phone. A build run from Xcode talks to Apple's sandbox, a TestFlight or
/// App Store build to production, and a token only works on its own one; when a phone's
/// side isn't known yet, both are tried and the one that works is remembered. Tokens
/// Apple reports as dead are deleted.
async function deliver(
  admin: SupabaseClient,
  jwt: string,
  device: DeviceToken,
  body: unknown,
) {
  const order: ("sandbox" | "production")[] = device.apns_env
    ? [device.apns_env]
    : ["production", "sandbox"]
  for (const env of order) {
    const host = env === "sandbox" ? "api.sandbox.push.apple.com" : "api.push.apple.com"
    const res = await fetch(`https://${host}/3/device/${device.token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": device.bundle_id,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "content-type": "application/json",
      },
      body: JSON.stringify(body),
    })
    if (res.ok) {
      if (device.apns_env !== env) {
        await admin.from("device_tokens").update({ apns_env: env }).eq("token", device.token)
      }
      return true
    }
    const reason = ((await res.json().catch(() => ({}))) as { reason?: string }).reason
    console.warn(`APNs ${env} ${res.status} ${reason ?? ""}`)
    if (res.status === 410 || reason === "Unregistered") {
      await admin.from("device_tokens").delete().eq("token", device.token)
      return false
    }
    // BadDeviceToken means "wrong side" while the side is unknown; anything else is final.
    if (reason !== "BadDeviceToken") return false
  }
  if (!device.apns_env) {
    await admin.from("device_tokens").delete().eq("token", device.token)
  }
  return false
}

// delete-account
//
// Task 18: account deletion has to complete entirely in-app, and deleting
// an auth.users row needs the service-role key — which never ships in the
// client (see CLAUDE.md's hard rule on secrets). This function is the only
// place that key is used.
//
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are
// injected automatically into every Edge Function's environment; nothing
// to configure by hand beyond deploying this file.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const PAGE = 1000

// Reads every row, not just the first page PostgREST returns.
async function readAll<T>(
  page: (from: number, to: number) => PromiseLike<{ data: unknown[] | null; error: unknown }>,
): Promise<T[]> {
  const rows: T[] = []
  for (let from = 0; ; from += PAGE) {
    const { data, error } = await page(from, from + PAGE - 1)
    if (error) throw error
    rows.push(...((data ?? []) as T[]))
    if ((data ?? []).length < PAGE) return rows
  }
}

// deno-lint-ignore no-explicit-any
async function removeAll(admin: any, bucket: string, paths: string[]) {
  for (let i = 0; i < paths.length; i += PAGE) {
    const { error } = await admin.storage.from(bucket).remove(paths.slice(i, i + PAGE))
    if (error) throw error
  }
}

Deno.serve(async (req) => {
  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing Authorization header" }), { status: 401 })
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

  // Identify the caller from their own JWT — never trust a client-supplied
  // user id, or anyone could ask this function to delete someone else.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  })
  const {
    data: { user },
    error: userError,
  } = await callerClient.auth.getUser()
  if (userError || !user) {
    return new Response(JSON.stringify({ error: "Not authenticated" }), { status: 401 })
  }

  const admin = createClient(supabaseUrl, serviceRoleKey)

  try {
    // Storage objects aren't reachable by a DB foreign key, so they're not
    // touched by auth.admin.deleteUser()'s cascade below — clear them first,
    // using the exact paths the app wrote (never a recursive folder walk, since
    // the DB already knows every path). Any failure stops here, before the
    // account goes: afterwards nothing would record which files were left, and
    // trying again is safe because removing a missing file is not an error.
    const uid = user.id
    const sessions = await readAll<{ id: string }>((from, to) =>
      admin.from("sessions").select("id").eq("user_id", uid).order("id").range(from, to)
    )
    const segments = await readAll<{ monitor_photo_path: string | null }>((from, to) =>
      admin
        .from("segments")
        .select("id, monitor_photo_path, sessions!inner(user_id)")
        .eq("sessions.user_id", uid)
        .order("id")
        .range(from, to)
    )
    const galleryPhotos = await readAll<{ path: string }>((from, to) =>
      admin
        .from("session_photos")
        .select("id, path, sessions!inner(user_id)")
        .eq("sessions.user_id", uid)
        .order("id")
        .range(from, to)
    )
    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("avatar_path")
      .eq("id", uid)
      .maybeSingle()
    if (profileError) throw profileError

    await removeAll(admin, "monitors", [
      ...segments.map((s) => s.monitor_photo_path).filter((p): p is string => !!p),
      ...galleryPhotos.map((p) => p.path),
    ])
    await removeAll(admin, "selfies", sessions.map((s) => `${uid}/${s.id}.jpg`))
    await removeAll(admin, "avatars", profile?.avatar_path ? [profile.avatar_path] : [])

  } catch (error) {
    const message = error instanceof Error ? error.message : (error as { message?: string }).message
    return new Response(JSON.stringify({ error: message ?? "Could not remove your photos" }), { status: 500 })
  }

  // Cascades profiles, sessions, segments, test_results, reactions,
  // comments, follows, blocks, reports, daily_totals — every FK in
  // docs/schema.sql back to profiles/auth.users reads `on delete cascade`.
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id)
  if (deleteError) {
    return new Response(JSON.stringify({ error: deleteError.message }), { status: 500 })
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  })
})

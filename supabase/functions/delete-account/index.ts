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

  // Storage objects aren't reachable by a DB foreign key, so they're not
  // touched by auth.admin.deleteUser()'s cascade below — clear them first,
  // using the exact paths StorageService.swift already writes (never a
  // recursive folder walk, since the DB already knows every path).
  const { data: segments } = await admin
    .from("segments")
    .select("monitor_photo_path, sessions!inner(user_id)")
    .eq("sessions.user_id", user.id)
  const monitorPaths = (segments ?? []).map((s: { monitor_photo_path: string }) => s.monitor_photo_path)
  if (monitorPaths.length > 0) {
    await admin.storage.from("monitors").remove(monitorPaths)
  }

  const { data: sessions } = await admin.from("sessions").select("id").eq("user_id", user.id)
  const selfiePaths = (sessions ?? []).map((s: { id: string }) => `${user.id}/${s.id}.jpg`)
  if (selfiePaths.length > 0) {
    await admin.storage.from("selfies").remove(selfiePaths)
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

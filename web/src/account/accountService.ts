import type { SupabaseClient } from "@supabase/supabase-js";

/** The rower's club name, or null when they're in none. */
export async function loadClubName(client: SupabaseClient): Promise<string | null> {
  const { data: session, error: sessionError } = await client.auth.getSession();
  if (sessionError) throw sessionError;
  const id = session.session?.user.id;
  if (!id) return null;
  const profile = await client.from("profiles").select("club_id").eq("id", id).single();
  if (profile.error) throw profile.error;
  const clubId = profile.data.club_id as string | null;
  if (!clubId) return null;
  const club = await client.from("clubs").select("name").eq("id", clubId).single();
  if (club.error) throw club.error;
  return (club.data.name as string | null) ?? null;
}

export async function leaveClub(client: SupabaseClient): Promise<void> {
  const { error } = await client.rpc("leave_club");
  if (error) throw error;
}

export async function signOut(client: SupabaseClient): Promise<void> {
  const { error } = await client.auth.signOut();
  if (error) throw error;
}

import type { SupabaseClient } from "@supabase/supabase-js";
import { normalised } from "../rules/username";
import type { ClubStatus, SetupState } from "./nextStep";

export type JoinOutcome = "joined" | "requested" | "invite_only";

export interface ClubResult {
  id: string;
  name: string;
  location: string | null;
  joinPolicy: "open" | "approval" | "invite_only";
  memberCount: number;
}

export interface ClubSummary {
  id: string;
  name: string;
}

async function userId(client: SupabaseClient): Promise<string | null> {
  const { data, error } = await client.auth.getSession();
  if (error) throw error;
  return data.session?.user.id ?? null;
}

export async function usernameAvailable(client: SupabaseClient, username: string): Promise<boolean> {
  const { data, error } = await client.rpc("username_available", { p_username: normalised(username) });
  if (error) throw error;
  return data === true;
}

export async function setUsername(client: SupabaseClient, username: string): Promise<string> {
  const { data, error } = await client.rpc("set_username", { p_username: normalised(username) });
  if (error) throw error;
  return data as string;
}

/** Saves just the date of birth ("YYYY-MM-DD"); the database refuses a date under 13. */
export async function saveBirthDate(client: SupabaseClient, birthDate: string): Promise<void> {
  const id = await userId(client);
  if (!id) throw new Error("Not signed in.");
  const { error } = await client
    .from("athlete_private")
    .upsert({ user_id: id, birth_date: birthDate }, { onConflict: "user_id" });
  if (error) throw error;
}

export async function clubForCode(client: SupabaseClient, code: string): Promise<string> {
  const { data, error } = await client.rpc("club_for_invite_code", { p_code: code.trim() });
  if (error) throw error;
  return data as string;
}

export async function joinWithCode(client: SupabaseClient, code: string): Promise<string> {
  const { data, error } = await client.rpc("join_club_with_code", { p_code: code.trim() });
  if (error) throw error;
  return data as string;
}

export async function joinClub(client: SupabaseClient, clubId: string): Promise<JoinOutcome> {
  const { data, error } = await client.rpc("join_club", { p_club: clubId });
  if (error) throw error;
  return data as JoinOutcome;
}

/** Takes back a waiting request, or clears a declined one. */
export async function cancelRequest(client: SupabaseClient): Promise<void> {
  const { error } = await client.rpc("cancel_join_request");
  if (error) throw error;
}

export async function searchClubs(client: SupabaseClient, text: string): Promise<ClubResult[]> {
  const query = client.from("clubs").select("*, profiles(count)");
  const { data, error } = text
    ? await query.ilike("name", `%${text}%`).order("name")
    : await query.order("name").limit(20);
  if (error) throw error;
  return ((data ?? []) as Record<string, unknown>[]).map((row) => {
    const counts = row.profiles as { count: number }[] | undefined;
    return {
      id: row.id as string,
      name: row.name as string,
      location: (row.location as string | null) ?? null,
      joinPolicy: (row.join_policy as ClubResult["joinPolicy"] | null) ?? "open",
      memberCount: counts?.[0]?.count ?? 0,
    };
  });
}

/** A signed-in rower's own setup state: username, birth date, club status and coach role. */
export async function loadSetupState(client: SupabaseClient): Promise<SetupState & { requestClub: ClubSummary | null; requestDeclined: boolean }> {
  const id = await userId(client);
  if (!id) {
    return { signedIn: false, username: null, birthDate: null, clubStatus: "none", isCoach: false, requestClub: null, requestDeclined: false };
  }
  const profile = await client.from("profiles").select("username, club_id, is_coach").eq("id", id).single();
  if (profile.error) throw profile.error;
  const priv = await client.from("athlete_private").select("birth_date").eq("user_id", id);
  if (priv.error) throw priv.error;

  let clubStatus: ClubStatus = profile.data.club_id ? "member" : "none";
  let requestClub: ClubSummary | null = null;
  let requestDeclined = false;
  if (clubStatus === "none") {
    const requests = await client.from("club_join_requests").select("status, clubs(id, name)").eq("user_id", id);
    const row = (requests.data as unknown as { status?: string; clubs: ClubSummary }[] | null)?.[0];
    if (row) {
      requestClub = row.clubs;
      requestDeclined = row.status === "declined";
      // A declined request sends the rower back to choose a club (as the app does).
      if (!requestDeclined) clubStatus = "requested";
    }
  }
  return {
    signedIn: true,
    username: (profile.data.username as string | null) ?? null,
    birthDate: ((priv.data?.[0]?.birth_date as string | null | undefined) ?? null),
    clubStatus,
    isCoach: profile.data.is_coach === true,
    requestClub,
    requestDeclined,
  };
}

/** Deletes the account (the `delete-account` function), then signs out. */
export async function deleteMyAccount(client: SupabaseClient): Promise<void> {
  const { error } = await client.functions.invoke("delete-account");
  if (error) throw error;
  // The account is already gone; a failing sign-out must not show an error for it.
  try {
    await client.auth.signOut({ scope: "local" });
  } catch {
    /* ignored */
  }
}

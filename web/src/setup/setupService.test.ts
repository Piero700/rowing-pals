import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import { nextStep } from "./nextStep";
import { loadSetupState } from "./setupService";

/** A client for a first Google sign-in: a session, but no `profiles` row until ensureProfileExists makes it. */
function firstGoogleSignIn(opts: { birthDate?: string | null; duplicate?: boolean } = {}) {
  let profile: Record<string, unknown> | null = null;
  const session = { user: { id: "u1", email: "jo@x.com", user_metadata: { full_name: "Jo Rower" } } };
  const profileUpsert = vi.fn((row: Record<string, unknown>, _options?: Record<string, unknown>) => {
    // ignoreDuplicates: a row already there is left alone, with no error.
    if (!profile) profile = { username: null, club_id: null, is_coach: false, ...row };
    return Promise.resolve({ error: null });
  });
  const from = vi.fn((table: string) => {
    if (table === "profiles") {
      return {
        select: () => ({
          eq: () => {
            const rows = profile && !opts.duplicate ? [profile] : [];
            const p = Promise.resolve({ data: rows, error: null });
            return Object.assign(p, {
              maybeSingle: () => Promise.resolve({ data: profile, error: null }),
              single: () =>
                Promise.resolve(
                  profile ? { data: profile, error: null } : { data: null, error: { code: "PGRST116", message: "0 rows" } },
                ),
            });
          },
        }),
        upsert: profileUpsert,
      };
    }
    if (table === "athlete_private") {
      return {
        select: () => ({ eq: () => Promise.resolve({ data: opts.birthDate ? [{ birth_date: opts.birthDate }] : [], error: null }) }),
        upsert: vi.fn().mockResolvedValue({ error: null }),
      };
    }
    // club_join_requests
    return { select: () => ({ eq: () => Promise.resolve({ data: [], error: null }) }) };
  });
  const auth = { getSession: vi.fn().mockResolvedValue({ data: { session }, error: null }) };
  return { client: { auth, from } as unknown as SupabaseClient, profileUpsert };
}

describe("loadSetupState", () => {
  it("makes the missing profile on a first Google sign-in and goes to the username step", async () => {
    const m = firstGoogleSignIn();
    const state = await loadSetupState(m.client);
    expect(m.profileUpsert).toHaveBeenCalledTimes(1);
    expect(m.profileUpsert.mock.calls[0][1]).toEqual({ onConflict: "id", ignoreDuplicates: true });
    expect(state.signedIn).toBe(true);
    expect(nextStep(state)).toBe("username");
  });

  it("goes to the birth date step once the username is set", async () => {
    const m = firstGoogleSignIn();
    await loadSetupState(m.client);
    // Simulate the username being chosen, then load again: no second insert is needed.
    const again = await loadSetupState(m.client);
    expect(nextStep({ ...again, username: "jo" })).toBe("birthDate");
  });

  it("two loads at once (StrictMode) don't error", async () => {
    const m = firstGoogleSignIn({ duplicate: true });
    const [a, b] = await Promise.all([loadSetupState(m.client), loadSetupState(m.client)]);
    expect(nextStep(a)).toBe("username");
    expect(nextStep(b)).toBe("username");
  });
});

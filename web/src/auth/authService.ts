import type { SupabaseClient } from "@supabase/supabase-js";
import { isEmail, normalised } from "../rules/username";
import { profileFromMetadata } from "./profileFromMetadata";

export const MINIMUM_PASSWORD_LENGTH = 6;
const WEAK_PASSWORD = `Choose a longer password: at least ${MINIMUM_PASSWORD_LENGTH} characters.`;

/** Thrown when the account exists but its email has not been confirmed yet. */
export class EmailNotConfirmedError extends Error {
  constructor() {
    super("Confirm your email first.");
  }
}

/** A plain-words failure from `username-auth`. */
export class UsernameAuthError extends Error {
  constructor(
    public code: string,
    message: string,
  ) {
    super(message);
  }
}

const cleanEmail = (text: string) => text.trim().toLowerCase();

/** Plain words for the errors people actually hit (same wording as the iPhone app). */
export function messageFor(error: unknown): string {
  if (error instanceof UsernameAuthError) return error.message;
  const e = error as { code?: string; message?: string } | null;
  switch (e?.code) {
    case "invalid_credentials":
      return "That email and password don't match.";
    case "otp_expired":
      return "That code has expired or isn't right. Tap Resend code for a new one.";
    case "user_already_exists":
    case "email_exists":
      return "There's already an account with that email. Sign in instead, or use Forgot password.";
    case "weak_password":
      return WEAK_PASSWORD;
    case "over_email_send_rate_limit":
    case "over_request_rate_limit":
      return "Too many emails just now. Wait a minute, then try again.";
  }
  return e?.message || "Something went wrong. Please try again.";
}

async function callUsernameAuth<T>(client: SupabaseClient, body: Record<string, unknown>): Promise<T> {
  const { data, error } = await client.functions.invoke("username-auth", { body });
  if (error) {
    let failure: { error?: string; message?: string } | null = null;
    try {
      const response = (error as { context?: Response }).context;
      failure = response ? await response.json() : null;
    } catch {
      failure = null;
    }
    throw new UsernameAuthError(
      failure?.error ?? "unknown",
      failure?.message ?? "Couldn’t sign in just now. Please try again.",
    );
  }
  return data as T;
}

async function startSession(client: SupabaseClient, body: Record<string, unknown>): Promise<void> {
  const tokens = await callUsernameAuth<{ access_token: string; refresh_token: string }>(client, body);
  const { error } = await client.auth.setSession({
    access_token: tokens.access_token,
    refresh_token: tokens.refresh_token,
  });
  if (error) throw error;
}

export async function signIn(client: SupabaseClient, identifier: string, password: string): Promise<void> {
  if (isEmail(identifier)) {
    const { error } = await client.auth.signInWithPassword({ email: cleanEmail(identifier), password });
    if (error) {
      if (error.code === "email_not_confirmed") throw new EmailNotConfirmedError();
      throw error;
    }
  } else {
    await startSession(client, { action: "sign-in", username: normalised(identifier), password });
  }
  await ensureProfileExists(client);
}

/** Returns true when a session came back (no code needed), false when the code screen is next. */
export async function signUp(
  client: SupabaseClient,
  input: { name: string; email: string; password: string; birthDate: string },
  now: Date = new Date(),
): Promise<boolean> {
  const { data, error } = await client.auth.signUp({
    email: cleanEmail(input.email),
    password: input.password,
    options: {
      data: {
        display_name: input.name.trim(),
        birth_date: input.birthDate,
        terms_accepted_at: now.toISOString(),
      },
    },
  });
  if (error) throw error;
  if (!data.session) return false;
  await ensureProfileExists(client);
  return true;
}

export async function verifySignupCode(client: SupabaseClient, email: string, code: string): Promise<void> {
  const { error } = await client.auth.verifyOtp({ email: cleanEmail(email), token: code, type: "signup" });
  if (error) throw error;
  await ensureProfileExists(client);
}

export async function resendSignupCode(client: SupabaseClient, email: string): Promise<void> {
  const { error } = await client.auth.resend({ email: cleanEmail(email), type: "signup" });
  if (error) throw error;
}

export async function sendReset(client: SupabaseClient, identifier: string): Promise<void> {
  if (isEmail(identifier)) {
    const { error } = await client.auth.resetPasswordForEmail(cleanEmail(identifier));
    if (error) throw error;
  } else {
    await callUsernameAuth(client, { action: "send-reset", username: normalised(identifier) });
  }
}

export async function resetWithCode(
  client: SupabaseClient,
  identifier: string,
  code: string,
  newPassword: string,
): Promise<void> {
  if (isEmail(identifier)) {
    const verified = await client.auth.verifyOtp({ email: cleanEmail(identifier), token: code, type: "recovery" });
    if (verified.error) throw verified.error;
    const updated = await client.auth.updateUser({ password: newPassword });
    if (updated.error) throw updated.error;
  } else {
    await startSession(client, { action: "reset", username: normalised(identifier), code, newPassword });
  }
  await ensureProfileExists(client);
}

export async function signInWithGoogle(client: SupabaseClient): Promise<void> {
  const { error } = await client.auth.signInWithOAuth({
    provider: "google",
    options: { redirectTo: `${location.origin}/go/` },
  });
  if (error) throw error;
}

/** Inserts the `profiles` row the first time this user has a session, then saves the birth date. */
export async function ensureProfileExists(client: SupabaseClient): Promise<void> {
  const { data: sessionData, error: sessionError } = await client.auth.getSession();
  if (sessionError) throw sessionError;
  const user = sessionData.session?.user;
  if (!user) return;

  const existing = await client.from("profiles").select("id").eq("id", user.id);
  if (existing.error) throw existing.error;
  if (existing.data && existing.data.length > 0) return;

  const meta = (user.user_metadata ?? {}) as Record<string, unknown>;
  const { displayName, termsAcceptedAt } = profileFromMetadata(meta, user.email ?? null);
  const inserted = await client
    .from("profiles")
    .insert({ id: user.id, display_name: displayName, terms_accepted_at: termsAcceptedAt });
  if (inserted.error) throw inserted.error;

  const birth = meta.birth_date;
  if (typeof birth === "string" && /^\d{4}-\d{2}-\d{2}$/.test(birth)) {
    // If it can't be saved now, the app asks for it again; sign-in is not blocked.
    await client.from("athlete_private").upsert({ user_id: user.id, birth_date: birth }, { onConflict: "user_id" });
  }
}

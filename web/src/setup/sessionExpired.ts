/** True when a failed request means the saved session is dead (expired or invalid token), not a bad connection. */
export function isSessionExpired(error: unknown): boolean {
  const e = error as { status?: number; code?: string; name?: string; message?: string } | null;
  if (!e) return false;
  if (e.status === 401) return true;
  if (e.code === "PGRST301" || e.code === "PGRST303") return true;
  if (e.name === "AuthSessionMissingError" || e.name === "AuthApiError" && e.status === 403) return true;
  return /jwt|invalid token|refresh token/i.test(e.message ?? "");
}

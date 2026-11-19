/**
 * Plain words for a failed answer or check-in. The week functions raise their own plain sentences
 * (Postgres code P0001, for example "Check-in opens 30 minutes before the start."), which are shown as they are.
 * Anything else (a database code, a network failure) gets a plain fallback, never the raw error.
 */
export function saveErrorMessage(error: unknown): string {
  const e = error as { code?: string; message?: string; name?: string } | null;
  if (e?.code === "P0001" && e.message?.trim()) return e.message.trim();
  if (e?.name === "TypeError" || /failed to fetch|network/i.test(e?.message ?? "")) {
    return "Couldn’t reach Rowing Pals. Check your connection and try again.";
  }
  return "Couldn’t save that. Try again.";
}

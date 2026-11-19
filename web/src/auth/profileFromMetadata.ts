const MAX_NAME = 40;

/** The profile name and agreement time for a new account, as SignInViewModel.ensureProfileExists picks them. */
export function profileFromMetadata(
  meta: Record<string, unknown>,
  email: string | null,
): { displayName: string; termsAcceptedAt: string } {
  const text = (key: string): string | null => {
    const value = meta[key];
    return typeof value === "string" && value.trim() !== "" ? value : null;
  };
  const emailName = email && email.includes("@") ? email.split("@")[0] || null : null;
  const name = text("display_name") ?? text("full_name") ?? text("name") ?? emailName ?? "Rower";
  const given = text("terms_accepted_at");
  const termsAcceptedAt = given && !Number.isNaN(Date.parse(given)) ? given : new Date().toISOString();
  return { displayName: [...name].slice(0, MAX_NAME).join(""), termsAcceptedAt };
}

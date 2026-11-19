export const MIN_LENGTH = 3;
export const MAX_LENGTH = 20;

/** What's typed, as it's stored: trimmed, lower case, without a leading @. */
export function normalised(text: string): string {
  const value = text.trim().toLowerCase();
  return value.startsWith("@") ? value.slice(1) : value;
}

/** Why a username can't be used, in plain words; null when it's fine (it may still be taken). */
export function problem(text: string): string | null {
  const value = normalised(text);
  const length = [...value].length;
  if (length < MIN_LENGTH) return `A username needs at least ${MIN_LENGTH} characters.`;
  if (length > MAX_LENGTH) return `A username can be at most ${MAX_LENGTH} characters.`;
  if (!/^[a-z0-9._]+$/.test(value)) return "Use only letters, numbers, full stops and underscores.";
  if (value.startsWith(".") || value.endsWith(".")) return "A username can’t start or end with a full stop.";
  return null;
}

/** Whether the box holds an email (anything with an @ after the first character). */
export function isEmail(text: string): boolean {
  return text.trim().indexOf("@") > 0;
}

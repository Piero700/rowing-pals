export type ClubStatus = "none" | "requested" | "member";
export type Step = "signIn" | "username" | "birthDate" | "club" | "waiting" | "week";

export interface SetupState {
  signedIn: boolean;
  username: string | null;
  birthDate: string | null;
  clubStatus: ClubStatus;
  isCoach: boolean;
}

/** Where a rower belongs next. Every signed-in visit goes through this. A coach lands on "week", which shows the coach notice. */
export function nextStep(s: SetupState): Step {
  if (!s.signedIn) return "signIn";
  if (!s.username) return "username";
  if (!s.birthDate) return "birthDate";
  if (s.clubStatus === "none") return "club";
  if (s.clubStatus === "requested") return "waiting";
  return "week";
}

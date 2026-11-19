/** Nobody younger can have an account. */
export const MINIMUM_AGE = 13;
/** Under this, a rower is a junior. */
export const ADULT_AGE = 18;
export const TOO_YOUNG_MESSAGE = "Rowing Pals is for people 13 and over.";

/** Whole years old on `today`, working on the local calendar. `birth` is "YYYY-MM-DD". */
export function ageOn(birth: string, today: Date): number {
  const [by, bm, bd] = birth.split("-").map(Number);
  let age = today.getFullYear() - by;
  const month = today.getMonth() + 1;
  if (month < bm || (month === bm && today.getDate() < bd)) age -= 1;
  return age;
}

export function isOldEnough(birth: string, today: Date): boolean {
  return ageOn(birth, today) >= MINIMUM_AGE;
}

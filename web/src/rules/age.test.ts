import { describe, expect, it } from "vitest";
import { ADULT_AGE, MINIMUM_AGE, TOO_YOUNG_MESSAGE, ageOn, isOldEnough } from "./age";

const day = (y: number, m: number, d: number) => new Date(y, m - 1, d, 15, 0);

describe("age rules", () => {
  it("has the constants", () => {
    expect(MINIMUM_AGE).toBe(13);
    expect(ADULT_AGE).toBe(18);
    expect(TOO_YOUNG_MESSAGE).toBe("Rowing Pals is for people 13 and over.");
  });
  it("is thirteen on the birthday, not the day before", () => {
    expect(isOldEnough("2013-11-17", day(2026, 11, 16))).toBe(false);
    expect(isOldEnough("2013-11-17", day(2026, 11, 17))).toBe(true);
    expect(ageOn("2013-11-17", day(2026, 11, 16))).toBe(12);
    expect(ageOn("2013-11-17", day(2026, 11, 17))).toBe(13);
  });
  it("handles a leap-day birthday", () => {
    expect(isOldEnough("2012-02-29", day(2025, 2, 27))).toBe(false);
    expect(isOldEnough("2012-02-29", day(2025, 3, 1))).toBe(true);
  });
  it("counts the eighteenth birthday", () => {
    expect(ageOn("2008-11-17", day(2026, 11, 16))).toBe(17);
    expect(ageOn("2008-11-17", day(2026, 11, 17))).toBe(18);
  });
});

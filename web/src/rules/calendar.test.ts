import { describe, expect, it } from "vitest";
import { canCheckIn, dayHeading, groupByLocalDay, timeText, weekRange, weekStart } from "./calendar";

const at = (y: number, m: number, d: number, h = 0, min = 0) => new Date(y, m - 1, d, h, min);

describe("calendar rules", () => {
  it("starts the week on the club's day", () => {
    const friday = at(2026, 10, 16, 12);
    expect(weekStart(friday, "monday")).toEqual(at(2026, 10, 12));
    expect(weekStart(friday, "sunday")).toEqual(at(2026, 10, 11));
  });
  it("a Monday starts its own week", () => {
    expect(weekStart(at(2026, 10, 19, 6, 30), "monday")).toEqual(at(2026, 10, 19));
  });
  it("gives next week for a Sunday-start club", () => {
    const r = weekRange("next", at(2026, 11, 19, 9), "sunday");
    expect(r.from).toEqual(at(2026, 11, 22));
    expect(r.to).toEqual(at(2026, 11, 29));
  });
  it("gives this week", () => {
    const r = weekRange("this", at(2026, 11, 19, 9), "monday");
    expect(r.from).toEqual(at(2026, 11, 16));
    expect(r.to).toEqual(at(2026, 11, 23));
  });
  it("opens check-in 30 minutes before and closes at the end", () => {
    const startsAt = at(2026, 10, 20, 6, 30);
    const endsAt = new Date(startsAt.getTime() + 90 * 60000);
    const p = { startsAt, endsAt, cancelled: false };
    const m = (n: number) => new Date(startsAt.getTime() + n * 60000);
    expect(canCheckIn(p, m(-31))).toBe(false);
    expect(canCheckIn(p, m(-30))).toBe(true);
    expect(canCheckIn(p, endsAt)).toBe(true);
    expect(canCheckIn(p, m(91))).toBe(false);
    expect(canCheckIn({ ...p, cancelled: true }, m(0))).toBe(false);
  });
  it("groups by local day across midnight", () => {
    const items = [{ s: at(2026, 10, 25, 23, 30) }, { s: at(2026, 10, 26, 0, 30) }, { s: at(2026, 10, 26, 6, 0) }];
    const groups = groupByLocalDay(items, (i) => i.s);
    expect(groups.map((g) => g.day)).toEqual(["2026-10-25", "2026-10-26"]);
    expect(groups[1].items).toHaveLength(2);
  });
  it("labels times and days", () => {
    expect(timeText(at(2026, 10, 20, 6, 30))).toBe("06:30");
    expect(timeText(at(2026, 10, 20, 18, 5))).toBe("18:05");
    expect(dayHeading(at(2026, 11, 25))).toBe("Wed 25 Nov");
    expect(dayHeading(at(2026, 10, 16))).toBe("Fri 16 Oct");
  });
});

import { buildWeek, type WeekData } from "./buildWeek";

const at = (day: number, h: number, m = 0) => new Date(2026, 10, day, h, m); // November 2026
const practice = (id: string, start: Date, over: Record<string, unknown> = {}) => ({
  id,
  title: id,
  place: null,
  startsAt: start,
  endsAt: new Date(start.getTime() + 90 * 60000),
  cancelled: false,
  ...over,
});
const data = (over: Partial<WeekData> = {}): WeekData => ({
  from: new Date(2026, 10, 23),
  to: new Date(2026, 10, 30),
  practices: [],
  events: [],
  myAnswers: {},
  myEventAnswers: {},
  ...over,
});

test("puts practices on their days in time order", () => {
  const days = buildWeek(
    data({ practices: [practice("late", at(24, 18)), practice("early", at(24, 6, 30)), practice("wed", at(25, 7))] }),
    at(23, 8),
  );
  expect(days.map((d) => d.day)).toEqual(["2026-11-24", "2026-11-25"]);
  expect(days[0].heading).toBe("Tue 24 Nov");
  expect(days[0].items.map((i) => (i.kind === "practice" ? i.practice.id : ""))).toEqual(["early", "late"]);
});

test("check-in is open 10 minutes before the start and closed after the end", () => {
  const p = practice("p", at(24, 7));
  const w = (now: Date) => {
    const item = buildWeek(data({ practices: [p] }), now)[0].items[0];
    return item.kind === "practice" && item.checkInOpen;
  };
  expect(w(at(24, 6, 50))).toBe(true);
  expect(w(at(24, 5, 0))).toBe(false);
  expect(w(at(24, 8, 31))).toBe(false);
});

test("shows Checked in with the time from checked_in_at", () => {
  const p = practice("p", at(24, 6, 30));
  const item = buildWeek(
    data({ practices: [p], myAnswers: { p: { answer: "going", reason: null, checkedInAt: at(24, 6, 24) } } }),
    at(24, 6, 40),
  )[0].items[0];
  expect(item.kind === "practice" && item.checkedInText).toBe("Checked in 06:24");
  expect(item.kind === "practice" && item.answer).toBe("going");
});

test("keeps a cancelled practice with no check-in", () => {
  const p = practice("p", at(24, 7), { cancelled: true });
  const item = buildWeek(data({ practices: [p] }), at(24, 6, 50))[0].items[0];
  expect(item.kind === "practice" && item.practice.cancelled).toBe(true);
  expect(item.kind === "practice" && item.checkInOpen).toBe(false);
});

test("a multi-day event shows once, on its first day inside the week", () => {
  const ev = { id: "e", name: "Regatta", firstDay: "2026-11-20", lastDay: "2026-11-25", place: null, note: null, asksAvailability: true };
  const days = buildWeek(data({ events: [ev], myEventAnswers: { e: { answer: "yes", reason: null } } }), at(23, 8));
  expect(days).toHaveLength(1);
  expect(days[0].day).toBe("2026-11-23");
  const item = days[0].items[0];
  expect(item.kind === "event" && item.answer).toBe("yes");
});

test("drops events outside the shown week", () => {
  const ev = { id: "e", name: "Later", firstDay: "2026-12-05", lastDay: "2026-12-05", place: null, note: null, asksAvailability: false };
  expect(buildWeek(data({ events: [ev] }), at(23, 8))).toEqual([]);
});

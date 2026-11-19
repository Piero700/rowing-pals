import { canCheckIn, dayHeading, groupByLocalDay, timeText } from "../rules/calendar";

export type PracticeAnswer = "going" | "cant";
export type EventAnswer = "yes" | "no";

export interface WeekPractice {
  id: string;
  title: string | null;
  place: string | null;
  startsAt: Date;
  endsAt: Date;
  cancelled: boolean;
}

export interface WeekEvent {
  id: string;
  name: string;
  /** "YYYY-MM-DD" local days. */
  firstDay: string;
  lastDay: string;
  place: string | null;
  note: string | null;
  asksAvailability: boolean;
}

export interface MyPracticeRow {
  answer: PracticeAnswer | null;
  reason: string | null;
  checkedInAt: Date | null;
}

export interface MyEventRow {
  answer: EventAnswer | null;
  reason: string | null;
}

export interface WeekData {
  /** Local midnight of the first day shown, and the exclusive end. */
  from: Date;
  to: Date;
  practices: WeekPractice[];
  events: WeekEvent[];
  myAnswers: Record<string, MyPracticeRow>;
  myEventAnswers: Record<string, MyEventRow>;
}

export type WeekItem =
  | {
      kind: "practice";
      practice: WeekPractice;
      answer: PracticeAnswer | null;
      reason: string | null;
      checkInOpen: boolean;
      checkedInText: string | null;
    }
  | { kind: "event"; event: WeekEvent; answer: EventAnswer | null; reason: string | null };

const pad = (n: number) => String(n).padStart(2, "0");
const dayKey = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const parseDay = (s: string) => {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
};

/** One entry per day that has something on, in date order; events (all day) first, then practices by time. */
export function buildWeek(data: WeekData, now: Date): { day: string; heading: string; items: WeekItem[] }[] {
  const fromKey = dayKey(data.from);
  const lastKey = dayKey(new Date(data.to.getFullYear(), data.to.getMonth(), data.to.getDate() - 1));

  const events: { item: WeekItem; start: Date }[] = [];
  for (const event of data.events) {
    if (event.lastDay < fromKey || event.firstDay > lastKey) continue;
    const shownOn = event.firstDay < fromKey ? fromKey : event.firstDay;
    const mine = data.myEventAnswers[event.id];
    events.push({
      start: parseDay(shownOn),
      item: { kind: "event", event, answer: mine?.answer ?? null, reason: mine?.reason ?? null },
    });
  }

  const practices = [...data.practices]
    .filter((p) => p.startsAt >= data.from && p.startsAt < data.to)
    .sort((a, b) => a.startsAt.getTime() - b.startsAt.getTime())
    .map((practice) => {
      const mine = data.myAnswers[practice.id];
      const item: WeekItem = {
        kind: "practice",
        practice,
        answer: mine?.answer ?? null,
        reason: mine?.reason ?? null,
        checkInOpen: canCheckIn(practice, now) && !mine?.checkedInAt,
        checkedInText: mine?.checkedInAt ? `Checked in ${timeText(mine.checkedInAt)}` : null,
      };
      return { item, start: practice.startsAt };
    });

  return groupByLocalDay([...events, ...practices], (e) => e.start)
    .sort((a, b) => (a.day < b.day ? -1 : 1))
    .map((g) => ({ day: g.day, heading: dayHeading(parseDay(g.day)), items: g.items.map((e) => e.item) }));
}

export type WeekStart = "monday" | "sunday";

const DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const pad = (n: number) => String(n).padStart(2, "0");

function addDays(date: Date, days: number): Date {
  // Calendar arithmetic in local time, so a clock change never shifts the day.
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + days);
}

/** Local midnight of the first day of the week holding `date`. */
export function weekStart(date: Date, startsOn: WeekStart): Date {
  const first = startsOn === "monday" ? 1 : 0;
  const back = (date.getDay() - first + 7) % 7;
  return addDays(date, -back);
}

/** This week or next, as local midnights; `to` is exclusive. */
export function weekRange(which: "this" | "next", today: Date, startsOn: WeekStart): { from: Date; to: Date } {
  const thisWeek = weekStart(today, startsOn);
  const from = which === "this" ? thisWeek : addDays(thisWeek, 7);
  return { from, to: addDays(from, 7) };
}

/** Check-in opens 30 minutes before the start and closes at the end. */
export function canCheckIn(p: { startsAt: Date; endsAt: Date; cancelled: boolean }, now: Date): boolean {
  return !p.cancelled && now.getTime() >= p.startsAt.getTime() - 30 * 60000 && now.getTime() <= p.endsAt.getTime();
}

/** Groups by local calendar day ("YYYY-MM-DD"), in order of first appearance. */
export function groupByLocalDay<T>(items: T[], start: (t: T) => Date): { day: string; items: T[] }[] {
  const groups: { day: string; items: T[] }[] = [];
  for (const item of items) {
    const d = start(item);
    const day = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
    const last = groups.find((g) => g.day === day);
    if (last) last.items.push(item);
    else groups.push({ day, items: [item] });
  }
  return groups;
}

/** "06:30". */
export function timeText(d: Date): string {
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/** "Wed 25 Nov". */
export function dayHeading(d: Date): string {
  return `${DAYS[d.getDay()]} ${d.getDate()} ${MONTHS[d.getMonth()]}`;
}

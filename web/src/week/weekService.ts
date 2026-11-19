import type { SupabaseClient } from "@supabase/supabase-js";
import type { WeekStart } from "../rules/calendar";
import { weekRange } from "../rules/calendar";
import type { EventAnswer, MyEventRow, MyPracticeRow, PracticeAnswer, WeekData, WeekEvent, WeekPractice } from "./buildWeek";

const pad = (n: number) => String(n).padStart(2, "0");
const dayText = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

type Row = Record<string, unknown>;

/** The club's week start, the rower's practices and events in the week, and their own answers. */
export async function load(client: SupabaseClient, which: "this" | "next", today: Date = new Date()): Promise<WeekData & { startsOn: WeekStart }> {
  const session = await client.auth.getSession();
  if (session.error) throw session.error;
  const userId = session.data.session?.user.id;
  if (!userId) throw new Error("Not signed in.");

  const profile = await client.from("profiles").select("club_id").eq("id", userId).single();
  if (profile.error) throw profile.error;
  let startsOn: WeekStart = "monday";
  if (profile.data.club_id) {
    const club = await client.from("clubs").select("week_starts_on").eq("id", profile.data.club_id).single();
    if (!club.error && club.data.week_starts_on === "sunday") startsOn = "sunday";
  }

  const { from, to } = weekRange(which, today, startsOn);
  const [practiceRes, eventRes] = await Promise.all([
    client.rpc("my_practices", { p_from: from.toISOString(), p_to: to.toISOString() }),
    client.rpc("my_events", { p_from: dayText(from) }),
  ]);
  if (practiceRes.error) throw practiceRes.error;
  if (eventRes.error) throw eventRes.error;

  const practices: WeekPractice[] = ((practiceRes.data ?? []) as Row[]).map((r) => ({
    id: r.id as string,
    title: (r.title as string | null) ?? null,
    place: (r.place as string | null) ?? null,
    startsAt: new Date(r.starts_at as string),
    endsAt: new Date(r.ends_at as string),
    cancelled: r.cancelled === true,
  }));
  const lastKey = dayText(new Date(to.getFullYear(), to.getMonth(), to.getDate() - 1));
  const events: WeekEvent[] = ((eventRes.data ?? []) as Row[])
    .map((r) => ({
      id: r.id as string,
      name: r.name as string,
      firstDay: r.first_day as string,
      lastDay: r.last_day as string,
      place: (r.place as string | null) ?? null,
      note: (r.note as string | null) ?? null,
      asksAvailability: r.asks_availability !== false,
    }))
    // my_events returns everything ending on or after the start; keep those overlapping the week.
    .filter((e) => e.firstDay <= lastKey);

  const myAnswers: Record<string, MyPracticeRow> = {};
  if (practices.length > 0) {
    const res = await client
      .from("attendance_responses")
      .select("practice_id, answer, reason, checked_in_at")
      .eq("user_id", userId)
      .in("practice_id", practices.map((p) => p.id));
    if (res.error) throw res.error;
    for (const r of (res.data ?? []) as Row[]) {
      myAnswers[r.practice_id as string] = {
        answer: (r.answer as PracticeAnswer | null) ?? null,
        reason: (r.reason as string | null) ?? null,
        checkedInAt: r.checked_in_at ? new Date(r.checked_in_at as string) : null,
      };
    }
  }
  const myEventAnswers: Record<string, MyEventRow> = {};
  if (events.length > 0) {
    const res = await client
      .from("event_responses")
      .select("event_id, answer, reason")
      .eq("user_id", userId)
      .in("event_id", events.map((e) => e.id));
    if (res.error) throw res.error;
    for (const r of (res.data ?? []) as Row[]) {
      myEventAnswers[r.event_id as string] = {
        answer: (r.answer as EventAnswer | null) ?? null,
        reason: (r.reason as string | null) ?? null,
      };
    }
  }
  return { from, to, practices, events, myAnswers, myEventAnswers, startsOn };
}

const clean = (reason?: string) => (reason?.trim() ? reason.trim() : null);

/** Available, Can't (with an optional reason), or null to clear. */
export async function respond(client: SupabaseClient, practiceId: string, answer: PracticeAnswer | null, reason?: string): Promise<void> {
  const { error } = await client.rpc("respond_practice", { p_practice: practiceId, p_answer: answer, p_reason: clean(reason) });
  if (error) throw error;
}

export async function checkIn(client: SupabaseClient, practiceId: string): Promise<void> {
  const { error } = await client.rpc("check_in_practice", { p_practice: practiceId });
  if (error) throw error;
}

/** "Can you race?": yes, no, or null to clear. */
export async function respondEvent(client: SupabaseClient, eventId: string, answer: EventAnswer | null, reason?: string): Promise<void> {
  const { error } = await client.rpc("respond_event", { p_event: eventId, p_answer: answer, p_reason: clean(reason) });
  if (error) throw error;
}

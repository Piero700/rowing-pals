import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { getSupabase } from "../lib/supabase";
import { isSessionExpired } from "../setup/sessionExpired";
import { buildWeek, type EventAnswer, type PracticeAnswer, type WeekData } from "./buildWeek";
import { DayCard } from "./DayCard";
import { saveErrorMessage } from "./saveErrorMessage";
import { checkIn, load, respond, respondEvent } from "./weekService";

type Which = "this" | "next";

/** Your week: Available / Can't for practices, Can you race? for races, check-in on the day. */
export function WeekScreen({
  isCoach,
  onAccount,
  onSessionExpired,
}: {
  isCoach: boolean;
  onAccount?: () => void;
  /** The saved session is dead: Home signs out locally and goes to sign in. */
  onSessionExpired?: () => void;
}) {
  const [which, setWhich] = useState<Which>("this");
  const [data, setData] = useState<WeekData | null>(null);
  const [failed, setFailed] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busyId, setBusyId] = useState<string | null>(null);
  const [now, setNow] = useState(() => new Date());

  // Each load gets a number; a slow earlier load that finishes after a tab switch is ignored.
  const latest = useRef(0);
  const refresh = useCallback(
    async (w: Which) => {
      const ticket = ++latest.current;
      try {
        const week = await load(getSupabase(), w);
        if (ticket !== latest.current) return;
        setData(week);
        setFailed(false);
      } catch (err) {
        if (ticket !== latest.current) return;
        if (isSessionExpired(err) && onSessionExpired) {
          onSessionExpired();
          return;
        }
        setFailed(true);
      }
    },
    [onSessionExpired],
  );

  useEffect(() => {
    setData(null);
    setErrors({});
    void refresh(which);
  }, [which, refresh]);

  // Check-in opens and closes on the clock, so keep "now" fresh.
  useEffect(() => {
    const t = setInterval(() => setNow(new Date()), 30000);
    return () => clearInterval(t);
  }, []);

  const days = useMemo(() => (data ? buildWeek(data, now) : []), [data, now]);

  const run = async (id: string, action: () => Promise<void>) => {
    setBusyId(id);
    setErrors((e) => {
      const { [id]: _drop, ...rest } = e;
      return rest;
    });
    try {
      await action();
      await refresh(which);
    } catch (err) {
      if (isSessionExpired(err) && onSessionExpired) {
        onSessionExpired();
        return;
      }
      setErrors((e) => ({ ...e, [id]: saveErrorMessage(err) }));
    } finally {
      setBusyId(null);
    }
  };

  const onPractice = (id: string, answer: PracticeAnswer | null, reason?: string) =>
    run(id, () => respond(getSupabase(), id, answer, reason));
  const onEvent = (id: string, answer: EventAnswer | null, reason?: string) =>
    run(id, () => respondEvent(getSupabase(), id, answer, reason));
  const onCheckIn = (id: string) => run(id, () => checkIn(getSupabase(), id));

  return (
    <main className="form-page">
      {isCoach && <p className="form-notice coach-notice" role="status">Coach tools are in the iPhone app for now.</p>}
      <h1>Your week</h1>
      {onAccount && (
        <button className="form-link" type="button" onClick={onAccount}>
          Account
        </button>
      )}
      <div className="week-tabs" role="tablist">
        {(["this", "next"] as const).map((w) => (
          <button
            key={w}
            className={`week-tab${which === w ? " week-tab-on" : ""}`}
            type="button"
            role="tab"
            aria-selected={which === w}
            onClick={() => setWhich(w)}
          >
            {w === "this" ? "This week" : "Next week"}
          </button>
        ))}
      </div>
      {failed ? (
        <>
          <p className="form-error">Couldn’t load your week. Check your connection and try again.</p>
          <button className="form-link" type="button" onClick={() => void refresh(which)}>Try again</button>
        </>
      ) : !data ? (
        <div aria-busy="true" />
      ) : days.length === 0 ? (
        <p className="form-notice">Nothing scheduled.</p>
      ) : (
        days.map((d) => (
          <DayCard
            key={d.day}
            heading={d.heading}
            items={d.items}
            errors={errors}
            busyId={busyId}
            onPractice={onPractice}
            onCheckIn={onCheckIn}
            onEvent={onEvent}
          />
        ))
      )}
    </main>
  );
}

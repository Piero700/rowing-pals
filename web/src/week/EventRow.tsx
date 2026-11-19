import { useState } from "react";
import type { EventAnswer, WeekItem } from "./buildWeek";
import { ReasonSheet } from "./ReasonSheet";

type Item = Extract<WeekItem, { kind: "event" }>;

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const short = (day: string) => {
  const [, m, d] = day.split("-").map(Number);
  return `${d} ${MONTHS[m - 1]}`;
};

export function EventRow({
  item,
  error,
  busy,
  onAnswer,
}: {
  item: Item;
  error: string | null;
  busy: boolean;
  onAnswer: (answer: EventAnswer | null, reason?: string) => void;
}) {
  const { event } = item;
  const [askingReason, setAskingReason] = useState(false);
  const dates = event.firstDay === event.lastDay ? null : `${short(event.firstDay)} – ${short(event.lastDay)}`;
  const sub = [dates, event.place].filter(Boolean).join(" · ");

  return (
    <div className="week-row">
      <div className="week-row-head">
        <span className="week-title">
          {event.name}
          {sub && <span className="week-sub">{sub}</span>}
          {event.note && <span className="week-sub">{event.note}</span>}
        </span>
      </div>
      {event.asksAvailability && (
        <>
          <div className="week-actions">
            <span className="week-question">Can you race?</span>
            <button
              className={`week-pill${item.answer === "yes" ? " week-pill-on" : ""}`}
              type="button"
              aria-pressed={item.answer === "yes"}
              disabled={busy}
              onClick={() => onAnswer(item.answer === "yes" ? null : "yes")}
            >
              Yes
            </button>
            <button
              className={`week-pill${item.answer === "no" ? " week-pill-off" : ""}`}
              type="button"
              aria-pressed={item.answer === "no"}
              disabled={busy}
              onClick={() => (item.answer === "no" ? onAnswer(null) : setAskingReason(true))}
            >
              No
            </button>
          </div>
          {askingReason && (
            <ReasonSheet
              title={`Can’t race ${event.name}`}
              initial={item.answer === "no" ? (item.reason ?? "") : ""}
              onCancel={() => setAskingReason(false)}
              onSave={(reason) => {
                setAskingReason(false);
                onAnswer("no", reason);
              }}
            />
          )}
        </>
      )}
      {error && <p className="form-error week-error" role="alert">{error}</p>}
    </div>
  );
}

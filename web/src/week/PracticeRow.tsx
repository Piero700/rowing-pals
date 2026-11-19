import { useState } from "react";
import { timeText } from "../rules/calendar";
import type { PracticeAnswer, WeekItem } from "./buildWeek";
import { ReasonSheet } from "./ReasonSheet";

type Item = Extract<WeekItem, { kind: "practice" }>;

export function PracticeRow({
  item,
  error,
  busy,
  onAnswer,
  onCheckIn,
}: {
  item: Item;
  error: string | null;
  busy: boolean;
  onAnswer: (answer: PracticeAnswer | null, reason?: string) => void;
  onCheckIn: () => void;
}) {
  const { practice } = item;
  const [askingReason, setAskingReason] = useState(false);
  const title = practice.title ?? "Practice";
  const where = [practice.place].filter(Boolean).join(" · ");

  return (
    <div className="week-row">
      <div className="week-row-head">
        <span className="week-time">{timeText(practice.startsAt)}</span>
        <span className="week-title">
          {title}
          {where && <span className="week-sub">{where}</span>}
        </span>
      </div>
      {practice.cancelled ? (
        <p className="week-cancelled">Cancelled</p>
      ) : (
        <>
          <div className="week-actions">
            <button
              className={`week-pill${item.answer === "going" ? " week-pill-on" : ""}`}
              type="button"
              aria-pressed={item.answer === "going"}
              disabled={busy}
              onClick={() => onAnswer(item.answer === "going" ? null : "going")}
            >
              Available
            </button>
            <button
              className={`week-pill${item.answer === "cant" ? " week-pill-off" : ""}`}
              type="button"
              aria-pressed={item.answer === "cant"}
              disabled={busy}
              onClick={() => (item.answer === "cant" ? onAnswer(null) : setAskingReason(true))}
            >
              Can’t
            </button>
            {item.checkedInText ? (
              <span className="week-checked">{item.checkedInText}</span>
            ) : (
              item.checkInOpen && (
                <button className="week-pill week-pill-on" type="button" disabled={busy} onClick={onCheckIn}>
                  Check in
                </button>
              )
            )}
          </div>
          {askingReason && (
            <ReasonSheet
              title={`Can’t make ${title}`}
              initial={item.answer === "cant" ? (item.reason ?? "") : ""}
              onCancel={() => setAskingReason(false)}
              onSave={(reason) => {
                setAskingReason(false);
                onAnswer("cant", reason);
              }}
            />
          )}
        </>
      )}
      {error && <p className="form-error week-error" role="alert">{error}</p>}
    </div>
  );
}

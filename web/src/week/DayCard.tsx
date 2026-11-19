import { GroupedCard } from "../components/GroupedCard";
import type { EventAnswer, PracticeAnswer, WeekItem } from "./buildWeek";
import { EventRow } from "./EventRow";
import { PracticeRow } from "./PracticeRow";

export function DayCard({
  heading,
  items,
  errors,
  busyId,
  onPractice,
  onCheckIn,
  onEvent,
}: {
  heading: string;
  items: WeekItem[];
  errors: Record<string, string>;
  busyId: string | null;
  onPractice: (id: string, answer: PracticeAnswer | null, reason?: string) => void;
  onCheckIn: (id: string) => void;
  onEvent: (id: string, answer: EventAnswer | null, reason?: string) => void;
}) {
  return (
    <section className="week-day">
      <h2 className="week-day-heading">{heading}</h2>
      <GroupedCard>
        {items.map((item) => {
          const id = item.kind === "practice" ? item.practice.id : item.event.id;
          return item.kind === "practice" ? (
            <PracticeRow
              key={id}
              item={item}
              error={errors[id] ?? null}
              busy={busyId === id}
              onAnswer={(a, r) => onPractice(id, a, r)}
              onCheckIn={() => onCheckIn(id)}
            />
          ) : (
            <EventRow key={id} item={item} error={errors[id] ?? null} busy={busyId === id} onAnswer={(a, r) => onEvent(id, a, r)} />
          );
        })}
      </GroupedCard>
    </section>
  );
}

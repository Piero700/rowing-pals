import { act, fireEvent, render, screen } from "@testing-library/react";
import { vi } from "vitest";
import type { WeekData } from "./buildWeek";
import { WeekScreen } from "./WeekScreen";

vi.mock("../lib/supabase", () => ({ getSupabase: () => ({}) }));
const load = vi.fn();
vi.mock("./weekService", () => ({
  load: (...args: unknown[]) => load(...args),
  respond: vi.fn(),
  respondEvent: vi.fn(),
  checkIn: vi.fn(),
}));

const soon = new Date(Date.now() + 2 * 86400000);
const week = (title: string): WeekData => ({
  from: new Date(soon.getFullYear(), soon.getMonth(), soon.getDate()),
  to: new Date(soon.getFullYear(), soon.getMonth(), soon.getDate() + 1),
  practices: [{ id: title, title, place: null, startsAt: soon, endsAt: new Date(soon.getTime() + 3600000), cancelled: false }],
  events: [],
  myAnswers: {},
  myEventAnswers: {},
});

test("a slow earlier load can't overwrite the week picked after it", async () => {
  let finishThis: (w: WeekData) => void = () => {};
  load.mockImplementation((_c: unknown, which: string) =>
    which === "this" ? new Promise<WeekData>((r) => (finishThis = r)) : Promise.resolve(week("Next week practice")),
  );
  render(<WeekScreen isCoach={false} />);
  fireEvent.click(screen.getByRole("tab", { name: "Next week" }));
  expect(await screen.findByText("Next week practice")).toBeInTheDocument();
  await act(async () => finishThis(week("This week practice")));
  expect(screen.queryByText("This week practice")).not.toBeInTheDocument();
  expect(screen.getByText("Next week practice")).toBeInTheDocument();
});

test("an expired session goes to sign in instead of showing an error", async () => {
  load.mockRejectedValue({ status: 401, message: "JWT expired" });
  const onSessionExpired = vi.fn();
  render(<WeekScreen isCoach={false} onSessionExpired={onSessionExpired} />);
  await act(async () => {});
  expect(onSessionExpired).toHaveBeenCalled();
  expect(screen.queryByText(/Couldn’t load your week/)).not.toBeInTheDocument();
});

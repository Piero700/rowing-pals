import { describe, expect, it } from "vitest";
import { saveErrorMessage } from "./saveErrorMessage";

describe("saveErrorMessage", () => {
  it("shows the week functions' own sentences", () => {
    expect(saveErrorMessage({ code: "P0001", message: "Check-in opens 30 minutes before the start." })).toBe(
      "Check-in opens 30 minutes before the start.",
    );
  });
  it("never shows a raw database error", () => {
    const m = saveErrorMessage({ code: "42501", message: 'new row violates row-level security policy for table "attendance_responses"' });
    expect(m).toBe("Couldn’t save that. Try again.");
    expect(saveErrorMessage({ code: "23503", message: "insert or update violates foreign key constraint" })).toBe("Couldn’t save that. Try again.");
    expect(saveErrorMessage(null)).toBe("Couldn’t save that. Try again.");
  });
  it("says a lost connection in plain words", () => {
    expect(saveErrorMessage(new TypeError("Failed to fetch"))).toBe("Couldn’t reach Rowing Pals. Check your connection and try again.");
  });
});

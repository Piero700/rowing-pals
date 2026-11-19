import { describe, expect, it } from "vitest";
import { profileFromMetadata } from "./profileFromMetadata";

describe("profileFromMetadata", () => {
  it("prefers display_name", () => {
    const p = profileFromMetadata({ display_name: "Joe Bloggs", full_name: "Other", terms_accepted_at: "2026-11-01T10:00:00Z" }, "j@x.com");
    expect(p.displayName).toBe("Joe Bloggs");
    expect(p.termsAcceptedAt).toBe("2026-11-01T10:00:00Z");
  });
  it("falls back through full_name, name, then the email's local part, then Rower", () => {
    expect(profileFromMetadata({ full_name: "Full N" }, "a@b.com").displayName).toBe("Full N");
    expect(profileFromMetadata({ name: "Nm" }, "a@b.com").displayName).toBe("Nm");
    expect(profileFromMetadata({ display_name: "  " }, "joe@example.com").displayName).toBe("joe");
    expect(profileFromMetadata({}, null).displayName).toBe("Rower");
  });
  it("cuts a long name to 40 characters", () => {
    expect(profileFromMetadata({ display_name: "x".repeat(45) }, null).displayName).toHaveLength(40);
  });
  it("uses now when no agreement time was given", () => {
    expect(Number.isNaN(Date.parse(profileFromMetadata({}, null).termsAcceptedAt))).toBe(false);
  });
});

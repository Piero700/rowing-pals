import { describe, expect, it } from "vitest";
import { isEmail, normalised, problem } from "./username";

describe("username rules", () => {
  it("accepts good usernames", () => {
    expect(problem("piero.ciobanu")).toBeNull();
    expect(problem("@Piero_C")).toBeNull();
  });
  it("normalises", () => {
    expect(normalised("  @Piero_C ")).toBe("piero_c");
  });
  it("explains problems", () => {
    expect(problem("pc")).toBe("A username needs at least 3 characters.");
    expect(problem("a".repeat(21))).toBe("A username can be at most 20 characters.");
    expect(problem("piero ciobanu")).toBe("Use only letters, numbers, full stops and underscores.");
    expect(problem("piero!")).toBe("Use only letters, numbers, full stops and underscores.");
    expect(problem(".piero")).toBe("A username can’t start or end with a full stop.");
    expect(problem("piero.")).toBe("A username can’t start or end with a full stop.");
  });
  it("tells an email from a username", () => {
    expect(isEmail("piero@uea.ac.uk")).toBe(true);
    expect(isEmail("piero.ciobanu")).toBe(false);
    expect(isEmail("@piero")).toBe(false);
  });
});

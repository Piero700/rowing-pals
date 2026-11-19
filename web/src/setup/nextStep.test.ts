import { nextStep } from "./nextStep";

const ready = { signedIn: true, username: "joe", birthDate: "2000-01-01", clubStatus: "member" as const, isCoach: false };

test("signed out goes to sign in", () => {
  expect(nextStep({ ...ready, signedIn: false })).toBe("signIn");
});
test("no username goes to username", () => {
  expect(nextStep({ ...ready, username: null })).toBe("username");
});
test("no birth date goes to birthDate", () => {
  expect(nextStep({ ...ready, birthDate: null })).toBe("birthDate");
});
test("no club goes to club", () => {
  expect(nextStep({ ...ready, clubStatus: "none" })).toBe("club");
});
test("a waiting request goes to waiting", () => {
  expect(nextStep({ ...ready, clubStatus: "requested" })).toBe("waiting");
});
test("a member goes to week", () => {
  expect(nextStep(ready)).toBe("week");
});
test("a coach member goes to week", () => {
  expect(nextStep({ ...ready, isCoach: true })).toBe("week");
});

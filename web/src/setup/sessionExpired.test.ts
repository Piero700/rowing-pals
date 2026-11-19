import { isSessionExpired } from "./sessionExpired";

test("expired or invalid sessions are recognised", () => {
  expect(isSessionExpired({ code: "PGRST301", message: "JWT expired" })).toBe(true);
  expect(isSessionExpired({ message: "JWT expired" })).toBe(true);
  expect(isSessionExpired({ status: 401, message: "x" })).toBe(true);
  expect(isSessionExpired({ name: "AuthSessionMissingError", message: "Auth session missing!" })).toBe(true);
});

test("ordinary failures are not treated as signed out", () => {
  expect(isSessionExpired(new TypeError("Failed to fetch"))).toBe(false);
  expect(isSessionExpired({ code: "42501", message: "permission denied" })).toBe(false);
  expect(isSessionExpired(null)).toBe(false);
});

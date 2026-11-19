import { render, screen } from "@testing-library/react";
import { App } from "./App";

test("the sign-in route shows Sign in", () => {
  render(<App />);
  expect(screen.getAllByText("Sign in").length).toBeGreaterThan(0);
});

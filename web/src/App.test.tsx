import { fireEvent, render, screen } from "@testing-library/react";
import { App } from "./App";

test("the sign-in route shows Sign in", () => {
  window.history.pushState({}, "", "/go/sign-in");
  render(<App />);
  expect(screen.getByRole("heading", { name: "Sign in" })).toBeInTheDocument();
});

test("create account refuses an under-13 date with the age copy", () => {
  window.history.pushState({}, "", "/go/create-account");
  render(<App />);
  const set = (label: string, value: string) =>
    fireEvent.change(screen.getByLabelText(label), { target: { value } });
  set("Name", "Joe");
  set("Email", "joe@example.com");
  set("Password", "secret123");
  set("Date of birth", `${new Date().getFullYear() - 10}-01-01`);
  fireEvent.click(screen.getByRole("checkbox"));
  fireEvent.click(screen.getByRole("button", { name: "Create account" }));
  expect(screen.getByRole("alert")).toHaveTextContent("Rowing Pals is for people 13 and over.");
});

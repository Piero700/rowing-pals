import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { vi } from "vitest";
import { AccountScreen } from "./AccountScreen";

const invoke = vi.fn();
const rpc = vi.fn();
const signOut = vi.fn();

function chain(result: unknown) {
  const c: Record<string, unknown> = {};
  c.select = () => c;
  c.eq = () => c;
  c.single = () => Promise.resolve(result);
  return c;
}

const client = {
  auth: { getSession: async () => ({ data: { session: { user: { id: "u1" } } }, error: null }), signOut },
  functions: { invoke },
  rpc,
  from: (table: string) =>
    table === "profiles" ? chain({ data: { club_id: "c1" }, error: null }) : chain({ data: { name: "Test BC" }, error: null }),
};
vi.mock("../lib/supabase", () => ({ getSupabase: () => client }));

const setup = () => {
  const props = { username: "joe", onBack: vi.fn(), onLeftClub: vi.fn(), onSignedOut: vi.fn() };
  render(<AccountScreen {...props} />);
  return props;
};

beforeEach(() => {
  invoke.mockReset().mockResolvedValue({ error: null });
  rpc.mockReset().mockResolvedValue({ error: null });
  signOut.mockReset().mockResolvedValue({ error: null });
});

test("shows the username and club", async () => {
  setup();
  expect(screen.getByText("@joe")).toBeInTheDocument();
  expect(await screen.findByText("Test BC")).toBeInTheDocument();
});

test("the first tap on Delete account confirms and does not call the function", () => {
  setup();
  fireEvent.click(screen.getByRole("button", { name: /Delete account/ }));
  expect(screen.getByText("This permanently deletes your account and everything you've posted. This can't be undone.")).toBeInTheDocument();
  expect(invoke).not.toHaveBeenCalled();
});

test("confirming Delete deletes then says so, even if sign-out then fails", async () => {
  signOut.mockRejectedValue(new Error("offline"));
  setup();
  fireEvent.click(screen.getByRole("button", { name: /Delete account/ }));
  fireEvent.click(screen.getByRole("button", { name: "Delete" }));
  expect(await screen.findByText("Your account has been deleted.")).toBeInTheDocument();
  expect(invoke).toHaveBeenCalledWith("delete-account");
});

test("a failed delete shows an error and keeps the account", async () => {
  invoke.mockResolvedValue({ error: { message: "Nope" } });
  setup();
  fireEvent.click(screen.getByRole("button", { name: /Delete account/ }));
  fireEvent.click(screen.getByRole("button", { name: "Delete" }));
  expect(await screen.findByRole("alert")).toHaveTextContent("Nope");
});

test("Leave club asks first, then calls leave_club and moves on", async () => {
  const props = setup();
  fireEvent.click(screen.getByRole("button", { name: /Leave club/ }));
  expect(rpc).not.toHaveBeenCalled();
  expect(screen.getByText(/Your sessions, metres and PBs stay yours/)).toBeInTheDocument();
  fireEvent.click(screen.getByRole("button", { name: "Leave" }));
  await waitFor(() => expect(props.onLeftClub).toHaveBeenCalled());
  expect(rpc).toHaveBeenCalledWith("leave_club");
});

test("Sign out signs out", async () => {
  const props = setup();
  fireEvent.click(screen.getByRole("button", { name: /Sign out/ }));
  await waitFor(() => expect(props.onSignedOut).toHaveBeenCalled());
});

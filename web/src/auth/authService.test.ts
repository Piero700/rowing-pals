import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import { resetWithCode, sendReset, signIn, signUp } from "./authService";

function mockClient() {
  const session = { user: { id: "u1", email: "j@x.com", user_metadata: { display_name: "Joe", birth_date: "2000-01-02" } } };
  const upsert = vi.fn().mockResolvedValue({ error: null });
  const insert = vi.fn().mockResolvedValue({ error: null });
  const from = vi.fn((table: string) =>
    table === "profiles"
      ? { select: () => ({ eq: () => Promise.resolve({ data: [{ id: "u1" }], error: null }) }), insert, upsert }
      : { upsert },
  );
  const auth = {
    signInWithPassword: vi.fn().mockResolvedValue({ error: null }),
    setSession: vi.fn().mockResolvedValue({ error: null }),
    getSession: vi.fn().mockResolvedValue({ data: { session }, error: null }),
    signUp: vi.fn().mockResolvedValue({ data: { session: null }, error: null }),
    resetPasswordForEmail: vi.fn().mockResolvedValue({ error: null }),
    verifyOtp: vi.fn().mockResolvedValue({ error: null }),
    updateUser: vi.fn().mockResolvedValue({ error: null }),
  };
  const functions = {
    invoke: vi.fn().mockResolvedValue({ data: { access_token: "a", refresh_token: "r", ok: true }, error: null }),
  };
  return { client: { auth, functions, from } as unknown as SupabaseClient, auth, functions, from, insert, upsert };
}

describe("authService", () => {
  it("signs in a username through username-auth and sets the session", async () => {
    const m = mockClient();
    await signIn(m.client, "@Joe.Bloggs", "pw1234");
    expect(m.functions.invoke).toHaveBeenCalledWith("username-auth", {
      body: { action: "sign-in", username: "joe.bloggs", password: "pw1234" },
    });
    expect(m.auth.setSession).toHaveBeenCalledWith({ access_token: "a", refresh_token: "r" });
    expect(m.auth.signInWithPassword).not.toHaveBeenCalled();
  });
  it("signs in an email with signInWithPassword", async () => {
    const m = mockClient();
    await signIn(m.client, " Joe@Example.com ", "pw1234");
    expect(m.auth.signInWithPassword).toHaveBeenCalledWith({ email: "joe@example.com", password: "pw1234" });
    expect(m.functions.invoke).not.toHaveBeenCalled();
  });
  it("sign-up sends the exact metadata keys and asks for the code when no session", async () => {
    const m = mockClient();
    const hasSession = await signUp(
      m.client,
      { name: " Joe ", email: "J@x.com", password: "pw1234", birthDate: "2000-01-02" },
      new Date("2026-11-19T10:00:00Z"),
    );
    expect(hasSession).toBe(false);
    expect(m.auth.signUp).toHaveBeenCalledWith({
      email: "j@x.com",
      password: "pw1234",
      options: { data: { display_name: "Joe", birth_date: "2000-01-02", terms_accepted_at: "2026-11-19T10:00:00.000Z" } },
    });
  });
  it("resets by email with the recovery code, then sets the password", async () => {
    const m = mockClient();
    await sendReset(m.client, "j@x.com");
    expect(m.auth.resetPasswordForEmail).toHaveBeenCalledWith("j@x.com");
    await resetWithCode(m.client, "j@x.com", "123456", "newpass1");
    expect(m.auth.verifyOtp).toHaveBeenCalledWith({ email: "j@x.com", token: "123456", type: "recovery" });
    expect(m.auth.updateUser).toHaveBeenCalledWith({ password: "newpass1" });
  });
  it("resets by username through the function", async () => {
    const m = mockClient();
    await sendReset(m.client, "joe");
    expect(m.functions.invoke).toHaveBeenCalledWith("username-auth", { body: { action: "send-reset", username: "joe" } });
    await resetWithCode(m.client, "joe", "123456", "newpass1");
    expect(m.functions.invoke).toHaveBeenLastCalledWith("username-auth", {
      body: { action: "reset", username: "joe", code: "123456", newPassword: "newpass1" },
    });
  });
});

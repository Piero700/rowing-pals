import { useEffect, useState, type FormEvent } from "react";
import { FormError, FormNotice } from "../auth/FormBits";
import { messageFor } from "../auth/authService";
import { getSupabase } from "../lib/supabase";
import { normalised, problem } from "../rules/username";
import { setUsername, usernameAvailable } from "./setupService";

export function UsernameScreen({ onDone }: { onDone: () => void }) {
  const [text, setText] = useState("");
  const [free, setFree] = useState<boolean | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const issue = text ? problem(text) : null;

  useEffect(() => {
    setFree(null);
    if (!text || problem(text)) return;
    let cancelled = false;
    const timer = setTimeout(async () => {
      try {
        const ok = await usernameAvailable(getSupabase(), text);
        if (!cancelled) setFree(ok);
      } catch {
        /* the check is a courtesy; saving still checks */
      }
    }, 400);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [text]);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setBusy(true);
    try {
      await setUsername(getSupabase(), text);
      onDone();
    } catch (e) {
      setError(messageFor(e));
    } finally {
      setBusy(false);
    }
  }

  const note = issue ?? (free === null ? null : free ? `@${normalised(text)} is free.` : "That username is taken. Try another.");
  return (
    <main className="form-page">
      <h1>Choose a username</h1>
      <p className="form-notice">
        It shows as @username on your profile, people can find you by it, and you can sign in with it instead of your email.
      </p>
      <div className="form-gap" />
      <form onSubmit={submit}>
        <section className="setup-field">
          <span className="setup-at">@</span>
          <input
            className="grouped-input"
            aria-label="Username"
            value={text}
            onChange={(e) => setText(e.target.value)}
            autoCapitalize="none"
            autoComplete="username"
            autoCorrect="off"
            autoFocus
          />
        </section>
        {issue || free === false ? <FormError message={note} /> : <FormNotice message={note ?? "Letters, numbers, full stops and underscores; 3 to 20 characters."} />}
        <FormError message={error} />
        <div className="form-gap" />
        <button className="form-button" type="submit" disabled={busy || !text || issue !== null || free === false}>
          Continue
        </button>
      </form>
    </main>
  );
}

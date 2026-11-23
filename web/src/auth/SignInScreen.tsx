import { useEffect, useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { GroupedCard } from "../components/GroupedCard";
import { getSupabase } from "../lib/supabase";
import { EmailNotConfirmedError, ensureProfileExists, messageFor, resendSignupCode, signIn, signInWithGoogle } from "./authService";
import { FormError, FieldRow } from "./FormBits";

export function SignInScreen() {
  const navigate = useNavigate();
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  // Back from Google: there is a session already; make sure the profile exists, then go in.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const client = getSupabase();
        const { data } = await client.auth.getSession();
        if (data.session && !cancelled) {
          await ensureProfileExists(client);
          navigate("/", { replace: true });
        }
      } catch {
        /* no session to continue */
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [navigate]);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const client = getSupabase();
      try {
        await signIn(client, identifier, password);
      } catch (e) {
        if (e instanceof EmailNotConfirmedError) {
          const email = identifier.trim().toLowerCase();
          await resendSignupCode(client, email).catch(() => undefined);
          navigate("/verify", { state: { email, notice: `Confirm your email first: we've sent a new code to ${email}.` } });
          return;
        }
        throw e;
      }
      navigate("/", { replace: true });
    } catch (e) {
      setError(messageFor(e));
    } finally {
      setBusy(false);
    }
  }

  async function google() {
    setError(null);
    try {
      await signInWithGoogle(getSupabase());
    } catch (e) {
      setError(messageFor(e));
    }
  }

  return (
    <main className="form-page">
      <h1>Sign in</h1>
      <div className="form-gap" />
      <form onSubmit={submit}>
        <GroupedCard>
          <FieldRow
            label="Email or username"
            value={identifier}
            onChange={(e) => setIdentifier(e.target.value)}
            autoCapitalize="none"
            autoComplete="username"
            autoCorrect="off"
          />
          <FieldRow
            label="Password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
          />
        </GroupedCard>
        <FormError message={error} />
        <div className="form-gap" />
        <button className="form-button" type="submit" disabled={busy || !identifier.trim() || !password}>
          Sign in
        </button>
      </form>
      <button className="form-link" type="button" onClick={() => navigate("/reset")}>
        Forgot password?
      </button>
      <button className="form-link" type="button" onClick={google}>
        Continue with Google
      </button>
      <button className="form-link" type="button" onClick={() => navigate("/create-account")}>
        Create account
      </button>
      <p className="form-legal">
        By continuing with Google you agree to the{" "}
        <a href="https://rowingpals.com/terms">Terms of Service</a> and{" "}
        <a href="https://rowingpals.com/privacy">Privacy Policy</a>.
      </p>
    </main>
  );
}

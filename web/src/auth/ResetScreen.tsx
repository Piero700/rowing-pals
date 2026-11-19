import { useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { GroupedCard } from "../components/GroupedCard";
import { getSupabase } from "../lib/supabase";
import { MINIMUM_PASSWORD_LENGTH, messageFor, resetWithCode, sendReset } from "./authService";
import { FormError, FormNotice, InputRow } from "./FormBits";

export function ResetScreen() {
  const navigate = useNavigate();
  const [identifier, setIdentifier] = useState("");
  const [sent, setSent] = useState(false);
  const [code, setCode] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function send(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setBusy(true);
    try {
      await sendReset(getSupabase(), identifier);
      setSent(true);
      setCode("");
      setNewPassword("");
    } catch (e) {
      setError(messageFor(e));
    } finally {
      setBusy(false);
    }
  }

  async function reset(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setNotice(null);
    if (newPassword.length < MINIMUM_PASSWORD_LENGTH) {
      return setError(`Choose a longer password: at least ${MINIMUM_PASSWORD_LENGTH} characters.`);
    }
    setBusy(true);
    try {
      await resetWithCode(getSupabase(), identifier, code.replace(/\D/g, ""), newPassword);
      navigate("/", { replace: true });
    } catch (e) {
      setError(messageFor(e));
    } finally {
      setBusy(false);
    }
  }

  async function resend() {
    setError(null);
    try {
      await sendReset(getSupabase(), identifier);
      setNotice("We've sent a new code.");
    } catch (e) {
      setError(messageFor(e));
    }
  }

  if (!sent) {
    return (
      <main className="form-page">
        <h1>Reset password</h1>
        <p className="form-notice">Enter your email or username and we’ll send a code.</p>
        <div className="form-gap" />
        <form onSubmit={send}>
          <GroupedCard>
            <InputRow
              label="Email or username"
              value={identifier}
              onChange={(e) => setIdentifier(e.target.value)}
              autoCapitalize="none"
              autoComplete="username"
            />
          </GroupedCard>
          <FormError message={error} />
          <div className="form-gap" />
          <button className="form-button" type="submit" disabled={busy || !identifier.trim()}>
            Send code
          </button>
        </form>
        <button className="form-link" type="button" onClick={() => navigate("/sign-in")}>
          Back to sign in
        </button>
      </main>
    );
  }

  return (
    <main className="form-page">
      <h1>Enter the code</h1>
      <p className="form-notice">If that account exists, we’ve emailed it a code. Type it in with a new password.</p>
      <div className="form-gap" />
      <form onSubmit={reset}>
        <GroupedCard>
          <InputRow
            label="Code"
            value={code}
            onChange={(e) => setCode(e.target.value)}
            inputMode="numeric"
            autoComplete="one-time-code"
          />
          <InputRow
            label="New password"
            type="password"
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
            autoComplete="new-password"
          />
        </GroupedCard>
        <FormError message={error} />
        <FormNotice message={notice} />
        <div className="form-gap" />
        <button className="form-button" type="submit" disabled={busy || code.replace(/\D/g, "").length < 6 || !newPassword}>
          Set password
        </button>
      </form>
      <button className="form-link" type="button" onClick={resend}>
        Resend code
      </button>
    </main>
  );
}

import { useState, type FormEvent } from "react";
import { Navigate, useLocation, useNavigate } from "react-router-dom";
import { GroupedCard } from "../components/GroupedCard";
import { getSupabase } from "../lib/supabase";
import { messageFor, resendSignupCode, verifySignupCode } from "./authService";
import { FormError, FormNotice, InputRow } from "./FormBits";

export function VerifyCodeScreen() {
  const navigate = useNavigate();
  const state = useLocation().state as { email?: string; notice?: string } | null;
  const email = state?.email ?? "";
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(state?.notice ?? null);
  const [busy, setBusy] = useState(false);

  if (!email) return <Navigate to="/sign-in" replace />;

  const clean = code.replace(/\D/g, "");
  const complete = clean.length >= 6 && clean.length <= 10;

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setNotice(null);
    setBusy(true);
    try {
      await verifySignupCode(getSupabase(), email, clean);
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
      await resendSignupCode(getSupabase(), email);
      setNotice(`We've sent a new code to ${email}.`);
    } catch (e) {
      setError(messageFor(e));
    }
  }

  return (
    <main className="form-page">
      <h1>Check your email</h1>
      <p className="form-notice">We’ve sent a code to {email}. Type it in to confirm your address.</p>
      <div className="form-gap" />
      <form onSubmit={submit}>
        <GroupedCard>
          <InputRow
            label="Code"
            value={code}
            onChange={(e) => setCode(e.target.value)}
            inputMode="numeric"
            autoComplete="one-time-code"
          />
        </GroupedCard>
        <FormError message={error} />
        <FormNotice message={notice} />
        <div className="form-gap" />
        <button className="form-button" type="submit" disabled={busy || !complete}>
          Confirm
        </button>
      </form>
      <button className="form-link" type="button" onClick={resend}>
        Resend code
      </button>
    </main>
  );
}

import { useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { GroupedCard } from "../components/GroupedCard";
import { getSupabase } from "../lib/supabase";
import { TOO_YOUNG_MESSAGE, isOldEnough } from "../rules/age";
import { MINIMUM_PASSWORD_LENGTH, messageFor, signUp } from "./authService";
import { FieldRow, FormError, InputRow } from "./FormBits";

export function CreateAccountScreen() {
  const navigate = useNavigate();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [birthDate, setBirthDate] = useState("");
  const [agreed, setAgreed] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    if (!agreed) return setError("Please agree to the Terms of Service to continue.");
    if (!birthDate) return setError("Please add your date of birth.");
    if (!isOldEnough(birthDate, new Date())) return setError(TOO_YOUNG_MESSAGE);
    if (password.length < MINIMUM_PASSWORD_LENGTH) {
      return setError(`Choose a longer password: at least ${MINIMUM_PASSWORD_LENGTH} characters.`);
    }
    setBusy(true);
    try {
      const signedIn = await signUp(getSupabase(), { name, email, password, birthDate });
      navigate(signedIn ? "/" : "/verify", { replace: signedIn, state: { email: email.trim().toLowerCase() } });
    } catch (e) {
      setError(messageFor(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="form-page">
      <h1>Create account</h1>
      <div className="form-gap" />
      <form onSubmit={submit}>
        <GroupedCard>
          <FieldRow label="Name" value={name} onChange={(e) => setName(e.target.value)} autoComplete="name" maxLength={40} />
          <FieldRow
            label="Email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoCapitalize="none"
            autoComplete="email"
          />
          <FieldRow
            label="Password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="new-password"
          />
          <InputRow label="Date of birth" type="date" value={birthDate} onChange={(e) => setBirthDate(e.target.value)} />
        </GroupedCard>
        <FormError message={error} />
        <p className="form-notice">
          <label>
            <input type="checkbox" checked={agreed} onChange={(e) => setAgreed(e.target.checked)} /> I agree to the{" "}
            <a href="https://rowingpals.com/terms">Terms of Service</a> and{" "}
            <a href="https://rowingpals.com/privacy">Privacy Policy</a>.
          </label>
        </p>
        <div className="form-gap" />
        <button className="form-button" type="submit" disabled={busy || !name.trim() || !email.trim() || !password}>
          Create account
        </button>
      </form>
      <button className="form-link" type="button" onClick={() => navigate("/sign-in")}>
        I already have an account
      </button>
    </main>
  );
}

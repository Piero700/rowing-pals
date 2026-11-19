import { useState, type FormEvent } from "react";
import { FormError, InputRow } from "../auth/FormBits";
import { messageFor } from "../auth/authService";
import { GroupedCard } from "../components/GroupedCard";
import { getSupabase } from "../lib/supabase";
import { isOldEnough, TOO_YOUNG_MESSAGE } from "../rules/age";
import { deleteMyAccount, saveBirthDate } from "./setupService";

export const UNDER_13_WARNING = "If the date is right, your account and everything in it will be deleted. This can't be undone.";

export function BirthDateScreen({ onDone, onDeleted }: { onDone: () => void; onDeleted: () => void }) {
  const [date, setDate] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [tooYoung, setTooYoung] = useState(false);
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    if (!isOldEnough(date, new Date())) {
      setTooYoung(true);
      return;
    }
    setBusy(true);
    try {
      await saveBirthDate(getSupabase(), date);
      onDone();
    } catch (e) {
      setError(messageFor(e));
    } finally {
      setBusy(false);
    }
  }

  async function remove() {
    setBusy(true);
    try {
      await deleteMyAccount(getSupabase());
      onDeleted();
    } catch (e) {
      setError(messageFor(e));
      setBusy(false);
    }
  }

  return (
    <main className="form-page">
      <h1>Your date of birth</h1>
      <p className="form-notice">
        Rowing Pals is for people 13 and over. Only you and your club’s coaches can see it, and under 18 your account starts private.
      </p>
      <div className="form-gap" />
      <form onSubmit={submit}>
        <GroupedCard>
          <InputRow
            label="Date of birth"
            type="date"
            value={date}
            max={new Date().toLocaleDateString("en-CA")}
            onChange={(e) => {
              setDate(e.target.value);
              setTooYoung(false);
            }}
          />
        </GroupedCard>
        <FormError message={error} />
        {tooYoung && (
          <div role="alertdialog" aria-label={TOO_YOUNG_MESSAGE}>
            <FormError message={TOO_YOUNG_MESSAGE} />
            <p className="form-notice">{UNDER_13_WARNING}</p>
            <button className="form-link" type="button" onClick={() => setTooYoung(false)}>
              Change date
            </button>
            <button className="form-link form-link-destructive" type="button" disabled={busy} onClick={remove}>
              Delete my account
            </button>
          </div>
        )}
        <div className="form-gap" />
        <button className="form-button" type="submit" disabled={busy || !date}>
          Continue
        </button>
      </form>
    </main>
  );
}

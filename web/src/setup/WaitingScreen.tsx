import { useState } from "react";
import { FormError } from "../auth/FormBits";
import { messageFor } from "../auth/authService";
import { getSupabase } from "../lib/supabase";
import { cancelRequest } from "./setupService";

export function WaitingScreen({ clubName, onDone }: { clubName: string | null; onDone: () => void }) {
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function cancel() {
    setError(null);
    setBusy(true);
    try {
      await cancelRequest(getSupabase());
      onDone();
    } catch (e) {
      setError(messageFor(e));
      setBusy(false);
    }
  }

  return (
    <main className="form-page">
      <h1>Waiting for approval</h1>
      <p className="form-notice">
        {clubName ? `${clubName} needs an admin to approve your request.` : "Your club needs an admin to approve your request."} You’ll
        be in as soon as they do.
      </p>
      <FormError message={error} />
      <div className="form-gap" />
      <button className="form-button" type="button" onClick={onDone}>
        Check again
      </button>
      <button className="form-link" type="button" disabled={busy} onClick={cancel}>
        Cancel request
      </button>
    </main>
  );
}

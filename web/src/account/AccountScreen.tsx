import { useEffect, useState } from "react";
import { FormError } from "../auth/FormBits";
import { messageFor } from "../auth/authService";
import { GroupedCard } from "../components/GroupedCard";
import { GroupedRow } from "../components/GroupedRow";
import { getSupabase } from "../lib/supabase";
import { deleteMyAccount } from "../setup/setupService";
import { leaveClub, loadClubName, signOut } from "./accountService";

type Confirming = "leave" | "delete" | null;

interface Props {
  username: string | null;
  onBack: () => void;
  onLeftClub: () => void;
  onSignedOut: () => void;
}

/** Username, club, Leave club, Sign out, Delete account. Confirmations sit on the page. */
export function AccountScreen({ username, onBack, onLeftClub, onSignedOut }: Props) {
  const [clubName, setClubName] = useState<string | null>(null);
  const [confirming, setConfirming] = useState<Confirming>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [deleted, setDeleted] = useState(false);

  useEffect(() => {
    let live = true;
    loadClubName(getSupabase())
      .then((name) => live && setClubName(name))
      .catch(() => undefined);
    return () => {
      live = false;
    };
  }, []);

  async function run(action: () => Promise<void>, then: () => void) {
    setError(null);
    setBusy(true);
    try {
      await action();
      then();
    } catch (e) {
      setError(messageFor(e));
      setBusy(false);
    }
  }

  if (deleted) {
    return (
      <main className="form-page">
        <h1>Account</h1>
        <p className="form-notice" role="status">Your account has been deleted.</p>
        <button className="form-button" type="button" onClick={onSignedOut}>
          Done
        </button>
      </main>
    );
  }

  const club = clubName ?? "your club";
  return (
    <main className="form-page">
      <button className="form-link" type="button" onClick={onBack}>
        Back to your week
      </button>
      <h1>Account</h1>
      <GroupedCard>
        <GroupedRow label="Username">{username ? `@${username}` : ""}</GroupedRow>
        <GroupedRow label="Club">{clubName ?? ""}</GroupedRow>
      </GroupedCard>
      <div className="form-gap" />
      <GroupedCard>
        <button className="grouped-button" type="button" disabled={busy} onClick={() => setConfirming("leave")}>
          <GroupedRow label="Leave club" />
        </button>
        <button className="grouped-button" type="button" disabled={busy} onClick={() => run(() => signOut(getSupabase()), onSignedOut)}>
          <GroupedRow label="Sign out" />
        </button>
        <button
          className="grouped-button form-link-destructive"
          type="button"
          disabled={busy}
          onClick={() => setConfirming("delete")}
        >
          <GroupedRow label="Delete account" />
        </button>
      </GroupedCard>
      <FormError message={error} />
      {confirming === "leave" && (
        <div role="alertdialog" aria-label={`Leave ${club}?`}>
          <p className="form-notice"><strong>Leave {club}?</strong></p>
          <p className="form-notice">Your sessions, metres and PBs stay yours. You can join a club again any time.</p>
          <button className="form-link form-link-destructive" type="button" disabled={busy} onClick={() => run(() => leaveClub(getSupabase()), onLeftClub)}>
            Leave
          </button>
          <button className="form-link" type="button" disabled={busy} onClick={() => setConfirming(null)}>
            Cancel
          </button>
        </div>
      )}
      {confirming === "delete" && (
        <div role="alertdialog" aria-label="Delete your account?">
          <p className="form-notice"><strong>Delete your account?</strong></p>
          <p className="form-notice">This permanently deletes your account and everything you've posted. This can't be undone.</p>
          <button
            className="form-link form-link-destructive"
            type="button"
            disabled={busy}
            onClick={() => run(() => deleteMyAccount(getSupabase()), () => setDeleted(true))}
          >
            Delete
          </button>
          <button className="form-link" type="button" disabled={busy} onClick={() => setConfirming(null)}>
            Cancel
          </button>
        </div>
      )}
    </main>
  );
}

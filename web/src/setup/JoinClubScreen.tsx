import { useEffect, useState, type FormEvent } from "react";
import { FormError, FormNotice, InputRow } from "../auth/FormBits";
import { messageFor } from "../auth/authService";
import { GroupedCard } from "../components/GroupedCard";
import { GroupedRow } from "../components/GroupedRow";
import { getSupabase } from "../lib/supabase";
import { clubForCode, joinClub, joinWithCode, searchClubs, type ClubResult } from "./setupService";

const policyNote = (c: ClubResult) =>
  c.joinPolicy === "invite_only" ? "Invitation only: use a code" : c.joinPolicy === "approval" ? "Approval needed" : "Open";

export function JoinClubScreen({ onDone }: { onDone: () => void }) {
  const [text, setText] = useState("");
  const [results, setResults] = useState<ClubResult[]>([]);
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let cancelled = false;
    const timer = setTimeout(async () => {
      try {
        const found = await searchClubs(getSupabase(), text.trim());
        if (!cancelled) setResults(found);
      } catch (e) {
        if (!cancelled) setError(messageFor(e));
      }
    }, 300);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [text]);

  async function run(action: () => Promise<void>) {
    setError(null);
    setBusy(true);
    try {
      await action();
      onDone();
    } catch (e) {
      setError(messageFor(e));
    } finally {
      setBusy(false);
    }
  }

  const join = (club: ClubResult) =>
    run(async () => {
      if ((await joinClub(getSupabase(), club.id)) === "invite_only") {
        throw new Error(`${club.name} is invitation only. Ask an admin for the club's code.`);
      }
    });

  function submitCode(event: FormEvent) {
    event.preventDefault();
    void run(async () => {
      const client = getSupabase();
      await clubForCode(client, code); // checks the code is real before joining
      await joinWithCode(client, code);
    });
  }

  return (
    <main className="form-page">
      <h1>Find your club</h1>
      <p className="form-notice">Search for your club to join it, or enter an invite code from a club admin.</p>
      <div className="form-gap" />
      <GroupedCard>
        <InputRow label="Search clubs" value={text} onChange={(e) => setText(e.target.value)} autoCapitalize="none" autoCorrect="off" />
      </GroupedCard>
      <div className="form-gap" />
      {results.length > 0 && (
        <GroupedCard>
          {results.map((club) => (
            <button key={club.id} className="grouped-button" type="button" disabled={busy} onClick={() => join(club)}>
              <GroupedRow label={club.name}>
                {[club.location, `${club.memberCount} ${club.memberCount === 1 ? "member" : "members"}`, policyNote(club)]
                  .filter(Boolean)
                  .join(" · ")}
              </GroupedRow>
            </button>
          ))}
        </GroupedCard>
      )}
      {results.length === 0 && <FormNotice message="No clubs found." />}
      <div className="form-gap" />
      <form onSubmit={submitCode}>
        <GroupedCard>
          <InputRow label="Invite code" value={code} onChange={(e) => setCode(e.target.value)} autoCapitalize="none" autoCorrect="off" />
        </GroupedCard>
        <FormError message={error} />
        <div className="form-gap" />
        <button className="form-button" type="submit" disabled={busy || !code.trim()}>
          Join with code
        </button>
      </form>
    </main>
  );
}

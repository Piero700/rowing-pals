import { useCallback, useEffect, useState } from "react";
import { Navigate } from "react-router-dom";
import { getSupabase } from "../lib/supabase";
import { BirthDateScreen } from "./BirthDateScreen";
import { JoinClubScreen } from "./JoinClubScreen";
import { nextStep } from "./nextStep";
import { loadSetupState } from "./setupService";
import { UsernameScreen } from "./UsernameScreen";
import { WaitingScreen } from "./WaitingScreen";
import { WeekScreen } from "../week/WeekScreen";

type Loaded = Awaited<ReturnType<typeof loadSetupState>>;

/** The signed-in front door: reads the rower's setup state and shows whichever screen comes next. */
export function Home() {
  const [state, setState] = useState<Loaded | null>(null);
  const [failed, setFailed] = useState(false);

  const load = useCallback(async () => {
    try {
      setState(await loadSetupState(getSupabase()));
      setFailed(false);
    } catch {
      setFailed(true);
    }
  }, []);
  useEffect(() => {
    void load();
  }, [load]);

  if (failed) {
    return (
      <main className="form-page">
        <p className="form-error">Couldn’t load your account. Check your connection and try again.</p>
        <button className="form-link" type="button" onClick={load}>Try again</button>
      </main>
    );
  }
  if (!state) return <main className="form-page" aria-busy="true" />;

  switch (nextStep(state)) {
    case "signIn":
      return <Navigate to="/sign-in" replace />;
    case "username":
      return <UsernameScreen onDone={load} />;
    case "birthDate":
      return <BirthDateScreen onDone={load} onDeleted={() => setState((s) => (s ? { ...s, signedIn: false } : s))} />;
    case "club":
      return <JoinClubScreen onDone={load} />;
    case "waiting":
      return <WaitingScreen clubName={state.requestClub?.name ?? null} onDone={load} />;
    case "week":
      return <WeekScreen isCoach={state.isCoach} />;
  }
}

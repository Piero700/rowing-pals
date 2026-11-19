import { GroupedCard } from "../components/GroupedCard";
import { GroupedRow } from "../components/GroupedRow";

export function SignInPage() {
  return (
    <main style={{ maxWidth: 480, margin: "0 auto", padding: "var(--space-4) var(--space-2)" }}>
      <h1>Sign in</h1>
      <div style={{ height: "var(--space-3)" }} />
      <GroupedCard>
        <GroupedRow label="Email" />
        <GroupedRow label="Password" />
      </GroupedCard>
    </main>
  );
}

/** Placeholder: the week screen is built in a later task. Coaches see the notice banner. */
export function WeekScreen({ isCoach }: { isCoach: boolean }) {
  return (
    <main className="form-page">
      {isCoach && <p className="form-notice coach-notice" role="status">Coach tools are in the iPhone app for now.</p>}
      <h1>Your week</h1>
    </main>
  );
}

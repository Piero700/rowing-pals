import type { ReactNode } from "react";

/** One card per group: 12 px corners, hairline edge. Web version of GroupedForm.swift. */
export function GroupedCard({ children }: { children: ReactNode }) {
  return (
    <section
      style={{
        background: "var(--surface-card)",
        border: "var(--hairline) solid var(--surface-line)",
        borderRadius: "var(--radius-card)",
        overflow: "hidden",
      }}
    >
      {children}
    </section>
  );
}

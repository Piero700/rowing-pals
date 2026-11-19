import type { ReactNode } from "react";

/** A 44 px row: label left, value right. Rows after the first get a hairline divider. */
export function GroupedRow({ label, children }: { label: string; children?: ReactNode }) {
  return (
    <div
      className="grouped-row"
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        gap: "var(--space-2)",
        minHeight: "var(--row-height)",
        padding: "0 var(--space-2)",
        fontSize: "var(--font-body)",
      }}
    >
      <span style={{ color: "var(--ink-primary)" }}>{label}</span>
      <span style={{ color: "var(--ink-secondary)" }}>{children}</span>
    </div>
  );
}

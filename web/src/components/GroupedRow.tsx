import type { ReactNode } from "react";

/** A 44 px row: label left, value right. Styling lives in tokens.css (.grouped-row). */
export function GroupedRow({ label, children }: { label: string; children?: ReactNode }) {
  return (
    <div className="grouped-row">
      <span className="grouped-row-label">{label}</span>
      <span className="grouped-row-value">{children}</span>
    </div>
  );
}

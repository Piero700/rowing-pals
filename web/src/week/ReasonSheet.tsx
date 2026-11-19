import { useState } from "react";

/** Asked after Can't: an optional reason that only the club's coaches see. */
export function ReasonSheet({
  title,
  initial,
  onSave,
  onCancel,
}: {
  title: string;
  initial: string;
  onSave: (reason: string) => void;
  onCancel: () => void;
}) {
  const [reason, setReason] = useState(initial);
  return (
    <div className="week-sheet" role="dialog" aria-label={title}>
      <input
        className="week-sheet-input"
        aria-label="Reason (optional)"
        placeholder="Reason (optional)"
        value={reason}
        maxLength={200}
        onChange={(e) => setReason(e.target.value)}
      />
      <p className="form-notice">Only coaches see this.</p>
      <div className="week-actions">
        <button className="week-pill" type="button" onClick={onCancel}>Cancel</button>
        <button className="week-pill week-pill-on" type="button" onClick={() => onSave(reason)}>Save</button>
      </div>
    </div>
  );
}

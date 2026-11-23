import type { InputHTMLAttributes } from "react";
import { GroupedRow } from "../components/GroupedRow";

/** A grouped row whose value side is a text box. */
export function InputRow({ label, ...input }: { label: string } & InputHTMLAttributes<HTMLInputElement>) {
  return (
    <GroupedRow label={label}>
      <input className="grouped-input" aria-label={label} {...input} />
    </GroupedRow>
  );
}

/** Errors sit under the card, in the error colour. */
export function FormError({ message }: { message: string | null }) {
  return message ? (
    <p className="form-error" role="alert">
      {message}
    </p>
  ) : null;
}

export function FormNotice({ message }: { message: string | null }) {
  return message ? <p className="form-notice">{message}</p> : null;
}

/** A typed field that fills its grouped row: the label is the hint inside the box and text starts from the left,
 *  as on the iPhone app's sign-in screens. Use InputRow only where a label sits left and a value right. */
export function FieldRow({ label, ...input }: { label: string } & InputHTMLAttributes<HTMLInputElement>) {
  return (
    <div className="grouped-row">
      <input className="grouped-field" placeholder={label} aria-label={label} {...input} />
    </div>
  );
}

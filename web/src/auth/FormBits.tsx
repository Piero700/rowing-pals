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

import { Suspense } from "react";
import SignUpClient from "./SignUpClient";

export default function SignUpPage() {
  return (
    <Suspense
      fallback={
        <div className="px-4 py-10 text-sm text-hubsom-ink/60">Loading…</div>
      }
    >
      <SignUpClient />
    </Suspense>
  );
}

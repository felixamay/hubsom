import { Suspense } from "react";
import SignInClient from "./SignInClient";

export default function SignInPage() {
  return (
    <Suspense
      fallback={
        <div className="px-4 py-10 text-sm text-hubsom-ink/60">Loading…</div>
      }
    >
      <SignInClient />
    </Suspense>
  );
}

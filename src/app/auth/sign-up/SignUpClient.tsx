"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { useSearchParams } from "next/navigation";
import { signUpAction, type AuthActionState } from "@/lib/auth/actions";
import {
  AuthError,
  AuthFooterLink,
  AuthShell,
  AuthSocialBlock,
  AuthSubmit,
  AuthEmailInput,
  NameField,
  PasswordField,
} from "@/components/auth/AuthForm";

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <AuthSubmit
      busy={pending}
      label="Create account"
      busyLabel="Creating your account…"
      tone="live"
    />
  );
}

const initial: AuthActionState = {};

export default function SignUpClient() {
  const params = useSearchParams();
  const callbackUrl = params.get("callbackUrl") || "/";
  const [state, action] = useActionState(signUpAction, initial);

  return (
    <AuthShell
      title="Create your account"
      subtitle="Join Hubsom to unlock live shopping, the marketplace, and selling tools."
      footer={
        <AuthFooterLink
          prompt="Already have an account?"
          href={`/auth/sign-in?callbackUrl=${encodeURIComponent(callbackUrl)}`}
          label="Sign in"
        />
      }
    >
      <form action={action} className="space-y-4">
        <input type="hidden" name="callbackUrl" value={callbackUrl} />
        <NameField />
        <AuthEmailInput />
        <PasswordField
          autoComplete="new-password"
          minLength={8}
          hint="Use at least 8 characters. You can change this later."
        />
        <AuthError message={state.error} />
        <SubmitButton />
      </form>
      <AuthSocialBlock callbackUrl={callbackUrl} />
      <p className="mt-4 text-center text-[11px] leading-relaxed text-hubsom-ink/45">
        After signup you’ll add a profile photo and finish your Hubsom profile.
      </p>
    </AuthShell>
  );
}

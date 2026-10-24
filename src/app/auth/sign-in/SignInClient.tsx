"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { useSearchParams } from "next/navigation";
import { signInAction, type AuthActionState } from "@/lib/auth/actions";
import {
  AuthError,
  AuthFooterLink,
  AuthShell,
  AuthSocialBlock,
  AuthSubmit,
  AuthEmailInput,
  PasswordField,
} from "@/components/auth/AuthForm";

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <AuthSubmit
      busy={pending}
      label="Sign in"
      busyLabel="Signing you in…"
      tone="forest"
    />
  );
}

const initial: AuthActionState = {};

export default function SignInClient() {
  const params = useSearchParams();
  const callbackUrl = params.get("callbackUrl") || "/";
  const [state, action] = useActionState(signInAction, initial);
  const queryError =
    params.get("error") === "CredentialsSignin"
      ? "Invalid email or password."
      : undefined;

  return (
    <AuthShell
      title="Welcome back"
      subtitle="Sign in to open Hubsom — live shopping, marketplace, and your store."
      footer={
        <AuthFooterLink
          prompt="New to Hubsom?"
          href={`/auth/sign-up?callbackUrl=${encodeURIComponent(callbackUrl)}`}
          label="Create an account"
        />
      }
    >
      <form action={action} className="space-y-4">
        <input type="hidden" name="callbackUrl" value={callbackUrl} />
        <AuthEmailInput />
        <PasswordField autoComplete="current-password" />
        <AuthError message={state.error || queryError} />
        <SubmitButton />
      </form>
      <AuthSocialBlock callbackUrl={callbackUrl} />
      <p className="mt-4 text-center text-[11px] leading-relaxed text-hubsom-ink/45">
        By continuing you agree to Hubsom’s commerce terms for Ghana buyers and
        sellers.
      </p>
    </AuthShell>
  );
}

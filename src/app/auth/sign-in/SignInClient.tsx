"use client";

import { useActionState, useEffect } from "react";
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
  const callbackUrl = params.get("callbackUrl") || "/account";
  const [state, action] = useActionState(signInAction, initial);

  useEffect(() => {
    const err = params.get("error");
    if (err === "CredentialsSignin") {
      /* shown via form state on submit */
    }
  }, [params]);

  return (
    <AuthShell
      title="Welcome back"
      subtitle="Sign in to shop live, manage orders, and run your Hubsom storefront."
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
        <AuthError
          message={
            state.error ||
            (params.get("error") === "CredentialsSignin"
              ? "Invalid email or password."
              : undefined)
          }
        />
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

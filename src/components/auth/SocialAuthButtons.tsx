"use client";

import { signIn } from "next-auth/react";
import { useEffect, useState } from "react";
import type { AuthProviderId } from "@/types/auth";

const LABELS: Record<Exclude<AuthProviderId, "credentials">, string> = {
  google: "Continue with Google",
  facebook: "Continue with Facebook",
  apple: "Continue with Apple",
};

export function SocialAuthButtons({
  callbackUrl = "/account",
}: {
  callbackUrl?: string;
}) {
  const [social, setSocial] = useState<AuthProviderId[]>([]);
  const [busy, setBusy] = useState<string | null>(null);

  useEffect(() => {
    void fetch("/api/auth/providers")
      .then((r) => r.json())
      .then((data: { social?: AuthProviderId[] }) => setSocial(data.social ?? []))
      .catch(() => undefined);
  }, []);

  if (!social.length) {
    return (
      <p className="rounded-xl border border-dashed border-hubsom-forest/20 bg-hubsom-mist/60 px-3 py-3 text-center text-xs text-hubsom-ink/60">
        Social sign-in is ready — add Google, Facebook, or Apple credentials in
        env to enable the buttons.
      </p>
    );
  }

  return (
    <div className="space-y-2">
      {social.map((provider) => {
        if (provider === "credentials") return null;
        return (
          <button
            key={provider}
            type="button"
            disabled={Boolean(busy)}
            onClick={() => {
              setBusy(provider);
              void signIn(provider, { callbackUrl });
            }}
            className="w-full rounded-xl border border-hubsom-forest/15 bg-white py-2.5 text-sm font-semibold text-hubsom-ink disabled:opacity-60"
          >
            {busy === provider ? "Redirecting…" : LABELS[provider]}
          </button>
        );
      })}
    </div>
  );
}

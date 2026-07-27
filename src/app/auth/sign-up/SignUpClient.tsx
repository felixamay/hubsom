"use client";

import Link from "next/link";
import { FormEvent, useState } from "react";
import { signIn } from "next-auth/react";
import { useRouter, useSearchParams } from "next/navigation";
import { SocialAuthButtons } from "@/components/auth/SocialAuthButtons";
import { BrandLogo } from "@/components/brand/BrandLogo";

export default function SignUpClient() {
  const router = useRouter();
  const params = useSearchParams();
  const callbackUrl = params.get("callbackUrl") || "/account/profile";
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const res = await fetch("/api/auth/signup", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, email, password }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "Could not create account");
        return;
      }

      const login = await signIn("credentials", {
        email,
        password,
        redirect: false,
        callbackUrl,
      });
      if (login?.error) {
        setError("Account created — please sign in");
        router.push("/auth/sign-in");
        return;
      }
      router.push(callbackUrl);
      router.refresh();
    } catch {
      setError("Network error");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mx-auto max-w-lg px-4 pb-10 pt-6">
      <BrandLogo href="/" heightClassName="h-9" />
      <h1 className="mt-6 font-display text-3xl font-extrabold text-hubsom-forest">
        Create account
      </h1>
      <p className="mt-2 text-sm text-hubsom-ink/65">
        Sign up with email or social to shop, sell, and go live.
      </p>

      <form
        onSubmit={onSubmit}
        className="mt-6 space-y-4 rounded-3xl border border-hubsom-forest/10 bg-white/80 p-4"
      >
        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">Full name</span>
          <input
            required
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5 outline-none focus:border-hubsom-leaf"
            autoComplete="name"
          />
        </label>
        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">Email</span>
          <input
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5 outline-none focus:border-hubsom-leaf"
            autoComplete="email"
          />
        </label>
        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">Password</span>
          <input
            type="password"
            required
            minLength={8}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5 outline-none focus:border-hubsom-leaf"
            autoComplete="new-password"
          />
          <span className="mt-1 block text-[11px] text-hubsom-ink/50">
            At least 8 characters
          </span>
        </label>
        {error && <p className="text-sm text-hubsom-live">{error}</p>}
        <button
          type="submit"
          disabled={busy}
          className="w-full rounded-xl bg-hubsom-live py-3 text-sm font-bold text-white disabled:opacity-60"
        >
          {busy ? "Creating…" : "Create account"}
        </button>
      </form>

      <div className="my-5 flex items-center gap-3 text-xs font-semibold uppercase tracking-[0.14em] text-hubsom-ink/40">
        <span className="h-px flex-1 bg-hubsom-forest/15" />
        Or
        <span className="h-px flex-1 bg-hubsom-forest/15" />
      </div>

      <SocialAuthButtons callbackUrl={callbackUrl} />

      <p className="mt-6 text-center text-sm text-hubsom-ink/65">
        Already have an account?{" "}
        <Link
          href={`/auth/sign-in?callbackUrl=${encodeURIComponent(callbackUrl)}`}
          className="font-bold text-hubsom-cyan"
        >
          Sign in
        </Link>
      </p>
    </div>
  );
}

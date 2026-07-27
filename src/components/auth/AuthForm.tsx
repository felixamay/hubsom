"use client";

import Link from "next/link";
import { useState } from "react";
import { Eye, EyeOff, Lock, Mail, UserRound } from "lucide-react";
import { BrandLogo } from "@/components/brand/BrandLogo";
import { SocialAuthButtons } from "@/components/auth/SocialAuthButtons";
import { cn } from "@/lib/utils";

export function AuthShell({
  title,
  subtitle,
  children,
  footer,
}: {
  title: string;
  subtitle: string;
  children: React.ReactNode;
  footer?: React.ReactNode;
}) {
  return (
    <div className="relative mx-auto flex min-h-[100svh] max-w-lg flex-col px-4 pb-10 pt-6">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-56 bg-[radial-gradient(ellipse_at_top,rgba(0,174,239,0.18),transparent_60%)]" />
      <div className="relative">
        <BrandLogo href="/" heightClassName="h-9" />
        <div className="mt-8">
          <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-hubsom-cyan">
            Hubsom Account
          </p>
          <h1 className="mt-2 font-display text-[1.85rem] font-extrabold leading-tight text-hubsom-forest">
            {title}
          </h1>
          <p className="mt-2 max-w-sm text-sm leading-relaxed text-hubsom-ink/65">
            {subtitle}
          </p>
        </div>

        <div className="mt-7 overflow-hidden rounded-[1.35rem] border border-hubsom-forest/10 bg-white/90 shadow-[0_24px_60px_-36px_rgba(6,18,31,0.45)] backdrop-blur">
          <div className="h-1 bg-gradient-to-r from-hubsom-cyan via-hubsom-blue to-hubsom-gold" />
          <div className="p-5 sm:p-6">{children}</div>
        </div>

        {footer ? (
          <div className="mt-6 text-center text-sm text-hubsom-ink/65">{footer}</div>
        ) : null}
      </div>
    </div>
  );
}

export function AuthField({
  label,
  hint,
  children,
}: {
  label: string;
  hint?: string;
  children: React.ReactNode;
}) {
  return (
    <label className="block">
      <span className="text-[13px] font-semibold text-hubsom-forest">{label}</span>
      <span className="relative mt-1.5 block">{children}</span>
      {hint ? (
        <span className="mt-1.5 block text-[11px] text-hubsom-ink/50">{hint}</span>
      ) : null}
    </label>
  );
}

export function authInputClass(hasIcon?: boolean, hasTrailing?: boolean) {
  return cn(
    "w-full rounded-xl border border-hubsom-forest/12 bg-hubsom-mist/40 px-3.5 py-3 text-sm text-hubsom-ink outline-none transition",
    "placeholder:text-hubsom-ink/35 focus:border-hubsom-cyan focus:bg-white focus:ring-4 focus:ring-hubsom-cyan/15",
    hasIcon && "pl-10",
    hasTrailing && "pr-11",
  );
}

export function AuthEmailInput(props: {
  name?: string;
  defaultValue?: string;
  required?: boolean;
  autoComplete?: string;
  placeholder?: string;
}) {
  return (
    <AuthField label="Email address">
      <Mail className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-hubsom-ink/35" />
      <input
        type="email"
        name={props.name ?? "email"}
        defaultValue={props.defaultValue}
        required={props.required ?? true}
        autoComplete={props.autoComplete ?? "email"}
        placeholder={props.placeholder ?? "you@email.com"}
        className={authInputClass(true)}
      />
    </AuthField>
  );
}

export function NameField() {
  return (
    <AuthField label="Full name">
      <UserRound className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-hubsom-ink/35" />
      <input
        type="text"
        name="name"
        required
        autoComplete="name"
        placeholder="Your name"
        className={authInputClass(true)}
      />
    </AuthField>
  );
}

export function PasswordField({
  name = "password",
  autoComplete,
  hint,
  minLength,
}: {
  name?: string;
  autoComplete: string;
  hint?: string;
  minLength?: number;
}) {
  const [show, setShow] = useState(false);
  return (
    <AuthField label="Password" hint={hint}>
      <Lock className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-hubsom-ink/35" />
      <input
        type={show ? "text" : "password"}
        name={name}
        required
        minLength={minLength}
        autoComplete={autoComplete}
        placeholder="••••••••"
        className={authInputClass(true, true)}
      />
      <button
        type="button"
        onClick={() => setShow((v) => !v)}
        className="absolute right-2.5 top-1/2 inline-flex h-8 w-8 -translate-y-1/2 items-center justify-center rounded-lg text-hubsom-ink/45 hover:bg-hubsom-mint hover:text-hubsom-forest"
        aria-label={show ? "Hide password" : "Show password"}
      >
        {show ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
      </button>
    </AuthField>
  );
}

export function AuthDivider() {
  return (
    <div className="my-5 flex items-center gap-3 text-[10px] font-bold uppercase tracking-[0.16em] text-hubsom-ink/35">
      <span className="h-px flex-1 bg-hubsom-forest/10" />
      Or continue with
      <span className="h-px flex-1 bg-hubsom-forest/10" />
    </div>
  );
}

export function AuthSubmit({
  busy,
  label,
  busyLabel,
  tone = "forest",
}: {
  busy: boolean;
  label: string;
  busyLabel: string;
  tone?: "forest" | "live";
}) {
  return (
    <button
      type="submit"
      disabled={busy}
      className={cn(
        "mt-1 w-full rounded-xl py-3 text-sm font-bold text-white shadow-sm transition disabled:cursor-not-allowed disabled:opacity-60",
        tone === "live"
          ? "bg-hubsom-live hover:brightness-105"
          : "bg-hubsom-forest hover:bg-hubsom-blue",
      )}
    >
      {busy ? busyLabel : label}
    </button>
  );
}

export function AuthSocialBlock({ callbackUrl }: { callbackUrl: string }) {
  return (
    <>
      <AuthDivider />
      <SocialAuthButtons callbackUrl={callbackUrl} />
    </>
  );
}

export function AuthFooterLink({
  prompt,
  href,
  label,
}: {
  prompt: string;
  href: string;
  label: string;
}) {
  return (
    <>
      {prompt}{" "}
      <Link href={href} className="font-bold text-hubsom-cyan hover:underline">
        {label}
      </Link>
    </>
  );
}

export function AuthError({ message }: { message?: string }) {
  if (!message) return null;
  return (
    <div className="rounded-xl border border-hubsom-live/25 bg-hubsom-live/10 px-3 py-2.5 text-sm text-hubsom-live">
      {message}
    </div>
  );
}

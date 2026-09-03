"use client";

import { FormEvent, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useSession } from "next-auth/react";
import { ProfileAvatarEditor } from "@/components/account/ProfileAvatarEditor";
import type { PublicUser } from "@/types/auth";

export default function ProfileEditorClient() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const welcome = searchParams.get("welcome") === "1";
  const nextPath = searchParams.get("next") || "/";
  const { data: session, status, update } = useSession();
  const [user, setUser] = useState<PublicUser | null>(null);
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [city, setCity] = useState("");
  const [region, setRegion] = useState("");
  const [bio, setBio] = useState("");
  const [image, setImage] = useState("");
  const [enableSeller, setEnableSeller] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (status === "unauthenticated") {
      router.replace("/auth/sign-in?callbackUrl=/account/profile");
    }
  }, [status, router]);

  useEffect(() => {
    if (status !== "authenticated") return;
    void fetch("/api/account/profile")
      .then((r) => r.json())
      .then((data: { user?: PublicUser }) => {
        if (!data.user) return;
        setUser(data.user);
        setName(data.user.name);
        setPhone(data.user.phone ?? "");
        setCity(data.user.city ?? "");
        setRegion(data.user.region ?? "");
        setBio(data.user.bio ?? "");
        setImage(data.user.image ?? "");
        setEnableSeller(
          data.user.role === "seller" || data.user.role === "both",
        );
      })
      .catch(() => undefined);
  }, [status]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setMessage(null);
    try {
      const res = await fetch("/api/account/profile", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name,
          phone,
          city,
          region,
          bio,
          image,
          enableSeller,
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "Could not save profile");
        return;
      }
      setUser(data.user);
      await update({
        user: {
          name: data.user.name,
          image: data.user.image,
          phone: data.user.phone,
          city: data.user.city,
          region: data.user.region,
          role: data.user.role,
          sellerId: data.user.sellerId,
        },
      });
      setMessage("Profile saved");
      if (welcome) {
        router.push(nextPath.startsWith("/") ? nextPath : "/");
        router.refresh();
        return;
      }
      router.refresh();
    } catch {
      setError("Network error");
    } finally {
      setBusy(false);
    }
  }

  if (status === "loading") {
    return (
      <div className="px-4 py-10 text-sm text-hubsom-ink/60">Loading profile…</div>
    );
  }

  if (status === "unauthenticated" || !session) {
    return (
      <div className="px-4 py-10 text-sm text-hubsom-ink/60">
        Redirecting to sign in…
      </div>
    );
  }

  const displayName = name || user?.name || session.user.name || "You";

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
        {welcome ? "Welcome to Hubsom" : "Your profile"}
      </h1>
      <p className="mt-2 text-sm text-hubsom-ink/65">
        {welcome
          ? "Add a profile photo and finish a few details so buyers and sellers recognize you."
          : "Complete your Hubsom identity for shopping, chat, and selling."}
      </p>

      {welcome ? (
        <div className="mt-4 rounded-2xl border border-hubsom-gold/35 bg-hubsom-gold/10 px-4 py-3 text-sm text-hubsom-ink">
          <p className="font-semibold text-hubsom-forest">Almost done</p>
          <p className="mt-0.5 text-hubsom-ink/70">
            Upload a clear face or brand photo — you can change it anytime in
            Account.
          </p>
        </div>
      ) : null}

      <form
        onSubmit={onSubmit}
        className="mt-5 space-y-4 rounded-3xl border border-hubsom-forest/10 bg-white/80 p-4"
      >
        <ProfileAvatarEditor
          image={image}
          name={displayName}
          emphasize={welcome}
          onUploaded={(url) => {
            setImage(url);
            setMessage("Profile photo updated");
          }}
        />

        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">Name</span>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
            className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5 outline-none focus:border-hubsom-leaf"
          />
        </label>

        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">Email</span>
          <input
            value={user?.email ?? session.user.email ?? ""}
            disabled
            className="mt-2 w-full rounded-xl border border-hubsom-forest/10 bg-hubsom-mist px-3 py-2.5 text-hubsom-ink/60"
          />
        </label>

        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">Phone</span>
          <input
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="+233…"
            className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5 outline-none focus:border-hubsom-leaf"
          />
        </label>

        <div className="grid grid-cols-2 gap-3">
          <label className="block">
            <span className="text-sm font-semibold text-hubsom-forest">City</span>
            <input
              value={city}
              onChange={(e) => setCity(e.target.value)}
              placeholder="Accra"
              className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5 outline-none focus:border-hubsom-leaf"
            />
          </label>
          <label className="block">
            <span className="text-sm font-semibold text-hubsom-forest">Region</span>
            <input
              value={region}
              onChange={(e) => setRegion(e.target.value)}
              placeholder="Greater Accra"
              className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5 outline-none focus:border-hubsom-leaf"
            />
          </label>
        </div>

        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">Bio</span>
          <textarea
            value={bio}
            onChange={(e) => setBio(e.target.value)}
            rows={3}
            className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5 outline-none focus:border-hubsom-leaf"
          />
        </label>

        <label className="flex items-center gap-3 text-sm font-medium text-hubsom-ink">
          <input
            type="checkbox"
            checked={enableSeller}
            onChange={(e) => setEnableSeller(e.target.checked)}
          />
          Enable seller storefront
        </label>

        {error && <p className="text-sm text-hubsom-live">{error}</p>}
        {message && <p className="text-sm text-hubsom-leaf">{message}</p>}

        <button
          type="submit"
          disabled={busy}
          className="w-full rounded-xl bg-hubsom-forest py-3 text-sm font-bold text-white disabled:opacity-60"
        >
          {busy
            ? "Saving…"
            : welcome
              ? "Save & continue"
              : "Save profile"}
        </button>

        {welcome ? (
          <Link
            href={nextPath.startsWith("/") ? nextPath : "/"}
            className="block text-center text-sm font-semibold text-hubsom-cyan"
          >
            Skip for now
          </Link>
        ) : null}
      </form>
    </div>
  );
}

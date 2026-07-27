"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useSession } from "next-auth/react";
import type { PublicUser } from "@/types/auth";

export default function ProfileEditorPage() {
  const router = useRouter();
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
      router.refresh();
    } catch {
      setError("Network error");
    } finally {
      setBusy(false);
    }
  }

  if (status === "loading" || !session) {
    return (
      <div className="px-4 py-10 text-sm text-hubsom-ink/60">Loading profile…</div>
    );
  }

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
        Your profile
      </h1>
      <p className="mt-2 text-sm text-hubsom-ink/65">
        Complete your Hubsom identity for shopping, chat, and selling.
      </p>

      <form
        onSubmit={onSubmit}
        className="mt-5 space-y-4 rounded-3xl border border-hubsom-forest/10 bg-white/80 p-4"
      >
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

        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">
            Avatar URL
          </span>
          <input
            value={image}
            onChange={(e) => setImage(e.target.value)}
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
          {busy ? "Saving…" : "Save profile"}
        </button>
      </form>
    </div>
  );
}

"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useSession } from "next-auth/react";
import type { UserAddress } from "@/types/auth";

export default function AddressesPage() {
  const router = useRouter();
  const { status } = useSession();
  const [addresses, setAddresses] = useState<UserAddress[]>([]);
  const [label, setLabel] = useState("Home");
  const [line1, setLine1] = useState("");
  const [line2, setLine2] = useState("");
  const [city, setCity] = useState("Accra");
  const [region, setRegion] = useState("Greater Accra");
  const [phone, setPhone] = useState("");
  const [isDefault, setIsDefault] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (status === "unauthenticated") {
      router.replace("/auth/sign-in?callbackUrl=/account/addresses");
    }
  }, [status, router]);

  async function load() {
    const res = await fetch("/api/account/addresses");
    const data = await res.json();
    if (res.ok) setAddresses(data.addresses ?? []);
  }

  useEffect(() => {
    if (status === "authenticated") void load();
  }, [status]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const res = await fetch("/api/account/addresses", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          label,
          line1,
          line2,
          city,
          region,
          phone,
          isDefault,
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "Could not save address");
        return;
      }
      setAddresses(data.addresses ?? []);
      setLine1("");
      setLine2("");
      setPhone("");
    } catch {
      setError("Network error");
    } finally {
      setBusy(false);
    }
  }

  async function remove(id: string) {
    await fetch(`/api/account/addresses?id=${encodeURIComponent(id)}`, {
      method: "DELETE",
    });
    await load();
  }

  if (status === "loading") {
    return (
      <div className="px-4 py-10 text-sm text-hubsom-ink/60">Loading…</div>
    );
  }

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
        Addresses
      </h1>
      <p className="mt-2 text-sm text-hubsom-ink/65">
        Delivery locations for Hubsom checkout.
      </p>

      <div className="mt-5 space-y-3">
        {!addresses.length && (
          <p className="rounded-2xl border border-dashed border-hubsom-forest/20 bg-white/50 px-4 py-8 text-center text-sm text-hubsom-ink/60">
            No addresses yet.
          </p>
        )}
        {addresses.map((addr) => (
          <div
            key={addr.id}
            className="rounded-2xl border border-hubsom-forest/10 bg-white/80 p-4"
          >
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="text-sm font-bold text-hubsom-ink">
                  {addr.label}
                  {addr.isDefault ? " · Default" : ""}
                </p>
                <p className="mt-1 text-sm text-hubsom-ink/70">{addr.line1}</p>
                {addr.line2 ? (
                  <p className="text-sm text-hubsom-ink/70">{addr.line2}</p>
                ) : null}
                <p className="text-sm text-hubsom-ink/70">
                  {addr.city}, {addr.region}
                </p>
                {addr.phone ? (
                  <p className="mt-1 text-xs text-hubsom-ink/55">{addr.phone}</p>
                ) : null}
              </div>
              <button
                type="button"
                onClick={() => void remove(addr.id)}
                className="text-xs font-semibold text-hubsom-live"
              >
                Remove
              </button>
            </div>
          </div>
        ))}
      </div>

      <form
        onSubmit={onSubmit}
        className="mt-6 space-y-3 rounded-3xl border border-hubsom-forest/10 bg-white/80 p-4"
      >
        <p className="text-sm font-bold text-hubsom-forest">Add address</p>
        <input
          value={label}
          onChange={(e) => setLabel(e.target.value)}
          placeholder="Label"
          className="w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5"
        />
        <input
          value={line1}
          onChange={(e) => setLine1(e.target.value)}
          placeholder="Street / landmark"
          required
          className="w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5"
        />
        <input
          value={line2}
          onChange={(e) => setLine2(e.target.value)}
          placeholder="Apartment / suite (optional)"
          className="w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5"
        />
        <div className="grid grid-cols-2 gap-3">
          <input
            value={city}
            onChange={(e) => setCity(e.target.value)}
            placeholder="City"
            className="w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5"
          />
          <input
            value={region}
            onChange={(e) => setRegion(e.target.value)}
            placeholder="Region"
            className="w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5"
          />
        </div>
        <input
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          placeholder="Phone"
          className="w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5"
        />
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={isDefault}
            onChange={(e) => setIsDefault(e.target.checked)}
          />
          Default address
        </label>
        {error && <p className="text-sm text-hubsom-live">{error}</p>}
        <button
          type="submit"
          disabled={busy}
          className="w-full rounded-xl bg-hubsom-forest py-3 text-sm font-bold text-white disabled:opacity-60"
        >
          {busy ? "Saving…" : "Save address"}
        </button>
      </form>
    </div>
  );
}

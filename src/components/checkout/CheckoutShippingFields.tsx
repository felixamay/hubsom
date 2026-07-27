"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import type { UserAddress } from "@/types/auth";
import type { OrderShipping } from "@/lib/data/orders";
import { cn } from "@/lib/utils";

export type ShippingFormValue = OrderShipping & {
  addressId?: string;
  saveAddress: boolean;
};

const empty: ShippingFormValue = {
  recipientName: "",
  phone: "",
  line1: "",
  line2: "",
  city: "Accra",
  region: "Greater Accra",
  notes: "",
  label: "Home",
  saveAddress: true,
};

export function CheckoutShippingFields({
  value,
  onChange,
  variant = "light",
}: {
  value: ShippingFormValue;
  onChange: (next: ShippingFormValue) => void;
  variant?: "light" | "dark";
}) {
  const [addresses, setAddresses] = useState<UserAddress[]>([]);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const res = await fetch("/api/account/addresses");
        if (!res.ok) {
          if (!cancelled) setLoaded(true);
          return;
        }
        const data = (await res.json()) as { addresses?: UserAddress[] };
        if (cancelled) return;
        const list = data.addresses ?? [];
        setAddresses(list);
        setLoaded(true);

        const preferred =
          list.find((a) => a.isDefault) ?? list[0] ?? undefined;
        if (preferred && !value.line1) {
          onChange({
            ...value,
            addressId: preferred.id,
            label: preferred.label,
            line1: preferred.line1,
            line2: preferred.line2 ?? "",
            city: preferred.city,
            region: preferred.region,
            phone: preferred.phone ?? value.phone,
            saveAddress: false,
          });
        }
      } catch {
        if (!cancelled) setLoaded(true);
      }
    })();
    return () => {
      cancelled = true;
    };
    // intentionally once on mount
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const dark = variant === "dark";
  const field = cn(
    "w-full rounded-xl border px-3 py-2.5 text-sm outline-none",
    dark
      ? "border-white/15 bg-white/10 text-white placeholder:text-white/40 focus:border-hubsom-gold"
      : "border-hubsom-forest/12 bg-white text-hubsom-ink placeholder:text-hubsom-ink/40 focus:border-hubsom-gold",
  );
  const labelCls = dark
    ? "text-[11px] font-semibold uppercase tracking-wide text-white/55"
    : "text-[11px] font-semibold uppercase tracking-wide text-hubsom-ink/50";

  function selectAddress(id: string) {
    if (id === "new") {
      onChange({
        ...empty,
        recipientName: value.recipientName,
        phone: value.phone,
        saveAddress: true,
      });
      return;
    }
    const addr = addresses.find((a) => a.id === id);
    if (!addr) return;
    onChange({
      ...value,
      addressId: addr.id,
      label: addr.label,
      line1: addr.line1,
      line2: addr.line2 ?? "",
      city: addr.city,
      region: addr.region,
      phone: addr.phone ?? value.phone,
      saveAddress: false,
    });
  }

  const selectedId = useMemo(() => {
    if (!value.addressId) return addresses.length ? "new" : "new";
    return value.addressId;
  }, [value.addressId, addresses.length]);

  return (
    <div className="space-y-3">
      <div className="flex items-end justify-between gap-2">
        <div>
          <p
            className={cn(
              "font-display text-lg font-bold",
              dark ? "text-white" : "text-hubsom-forest",
            )}
          >
            Shipping
          </p>
          <p className={cn("text-xs", dark ? "text-white/55" : "text-hubsom-ink/55")}>
            Sent to the seller with your order.
          </p>
        </div>
        <Link
          href="/account/addresses"
          className={cn(
            "text-[11px] font-semibold",
            dark ? "text-hubsom-gold" : "text-hubsom-cyan",
          )}
        >
          Manage
        </Link>
      </div>

      {loaded && addresses.length > 0 ? (
        <label className="block space-y-1.5">
          <span className={labelCls}>Saved address</span>
          <select
            value={selectedId}
            onChange={(e) => selectAddress(e.target.value)}
            className={field}
          >
            {addresses.map((a) => (
              <option key={a.id} value={a.id}>
                {a.label}
                {a.isDefault ? " (default)" : ""} — {a.line1}
              </option>
            ))}
            <option value="new">Use a new address</option>
          </select>
        </label>
      ) : null}

      <div className="grid gap-3 sm:grid-cols-2">
        <label className="block space-y-1.5 sm:col-span-2">
          <span className={labelCls}>Recipient name</span>
          <input
            value={value.recipientName}
            onChange={(e) =>
              onChange({ ...value, recipientName: e.target.value })
            }
            placeholder="Full name"
            className={field}
            required
          />
        </label>
        <label className="block space-y-1.5 sm:col-span-2">
          <span className={labelCls}>Phone (MoMo / delivery)</span>
          <input
            value={value.phone}
            onChange={(e) => onChange({ ...value, phone: e.target.value })}
            placeholder="e.g. 024 xxx xxxx"
            className={field}
            required
          />
        </label>
        <label className="block space-y-1.5 sm:col-span-2">
          <span className={labelCls}>Address line 1</span>
          <input
            value={value.line1}
            onChange={(e) =>
              onChange({ ...value, line1: e.target.value, addressId: undefined })
            }
            placeholder="Street, landmark, house no."
            className={field}
            required
          />
        </label>
        <label className="block space-y-1.5 sm:col-span-2">
          <span className={labelCls}>Address line 2 (optional)</span>
          <input
            value={value.line2 ?? ""}
            onChange={(e) =>
              onChange({ ...value, line2: e.target.value, addressId: undefined })
            }
            placeholder="Apartment, estate, gate code"
            className={field}
          />
        </label>
        <label className="block space-y-1.5">
          <span className={labelCls}>City</span>
          <input
            value={value.city}
            onChange={(e) =>
              onChange({ ...value, city: e.target.value, addressId: undefined })
            }
            className={field}
            required
          />
        </label>
        <label className="block space-y-1.5">
          <span className={labelCls}>Region</span>
          <input
            value={value.region}
            onChange={(e) =>
              onChange({
                ...value,
                region: e.target.value,
                addressId: undefined,
              })
            }
            className={field}
            required
          />
        </label>
        <label className="block space-y-1.5 sm:col-span-2">
          <span className={labelCls}>Delivery note (optional)</span>
          <input
            value={value.notes ?? ""}
            onChange={(e) => onChange({ ...value, notes: e.target.value })}
            placeholder="Call on arrival, leave with security…"
            className={field}
          />
        </label>
      </div>

      <label
        className={cn(
          "flex items-center gap-2 text-xs font-medium",
          dark ? "text-white/70" : "text-hubsom-ink/70",
        )}
      >
        <input
          type="checkbox"
          checked={value.saveAddress}
          onChange={(e) =>
            onChange({ ...value, saveAddress: e.target.checked })
          }
          className="rounded border-hubsom-forest/30"
        />
        Save this address for next time
      </label>
    </div>
  );
}

export function emptyShippingForm(
  defaults?: Partial<ShippingFormValue>,
): ShippingFormValue {
  return { ...empty, ...defaults };
}

export function shippingPayload(value: ShippingFormValue) {
  return {
    addressId: value.addressId,
    saveAddress: value.saveAddress,
    shipping: {
      recipientName: value.recipientName,
      phone: value.phone,
      line1: value.line1,
      line2: value.line2 || undefined,
      city: value.city,
      region: value.region,
      notes: value.notes || undefined,
      label: value.label || undefined,
    },
  };
}

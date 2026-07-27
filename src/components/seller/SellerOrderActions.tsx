"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import type { OrderStatus } from "@/lib/data/orders";

export function SellerOrderActions({
  orderId,
  status,
  buyerUserId,
}: {
  orderId: string;
  status: OrderStatus;
  buyerUserId?: string;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function mark(next: OrderStatus) {
    setError(null);
    startTransition(async () => {
      try {
        const res = await fetch(`/api/seller/orders/${orderId}`, {
          method: "PATCH",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ status: next }),
        });
        const data = await res.json();
        if (!res.ok) {
          setError(data.error ?? "Could not update order");
          return;
        }
        router.refresh();
      } catch {
        setError("Network error");
      }
    });
  }

  return (
    <div className="flex flex-wrap items-center gap-2 pt-1">
      {status !== "fulfilled" && status !== "cancelled" ? (
        <button
          type="button"
          disabled={pending}
          onClick={() => mark("fulfilled")}
          className="rounded-xl bg-hubsom-forest px-3 py-2 text-xs font-bold text-white disabled:opacity-50"
        >
          Mark fulfilled
        </button>
      ) : null}
      {status === "pending_payment" ? (
        <button
          type="button"
          disabled={pending}
          onClick={() => mark("paid")}
          className="rounded-xl border border-hubsom-forest/15 bg-white px-3 py-2 text-xs font-bold text-hubsom-forest disabled:opacity-50"
        >
          Mark paid
        </button>
      ) : null}
      {buyerUserId ? (
        <Link
          href={`/messages/${buyerUserId}`}
          className="rounded-xl border border-hubsom-forest/15 bg-white px-3 py-2 text-xs font-bold text-hubsom-forest"
        >
          Message buyer
        </Link>
      ) : null}
      {error ? (
        <p className="w-full text-xs font-medium text-hubsom-live">{error}</p>
      ) : null}
    </div>
  );
}

"use client";

import Link from "next/link";
import { useState } from "react";
import { formatGhs } from "@/lib/currency";
import { getEffectivePrice, getProduct } from "@/lib/data/products";
import { useCartStore } from "@/lib/stores/cart";

export default function CartPage() {
  const items = useCartStore((s) => s.items);
  const setQuantity = useCartStore((s) => s.setQuantity);
  const removeItem = useCartStore((s) => s.removeItem);
  const clear = useCartStore((s) => s.clear);
  const [status, setStatus] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const lines = items
    .map((item) => {
      const product = getProduct(item.productId);
      if (!product) return null;
      const unit = getEffectivePrice(product);
      return { item, product, unit, total: unit * item.quantity };
    })
    .filter(Boolean);

  const subtotal = lines.reduce((sum, l) => sum + (l?.total ?? 0), 0);

  async function checkout() {
    setLoading(true);
    setStatus(null);
    try {
      const res = await fetch("/api/checkout", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          items: items.map((i) => ({
            productId: i.productId,
            quantity: i.quantity,
          })),
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        setStatus(data.error ?? "Checkout failed");
        return;
      }
      clear();
      setStatus(`Order ${data.orderId} confirmed · ${formatGhs(data.subtotalGhs)}`);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="mx-auto max-w-3xl px-4 py-10 sm:px-6">
      <h1 className="font-display text-4xl font-extrabold text-hubsom-forest">Cart</h1>
      <p className="mt-2 text-hubsom-ink/70">
        Unified cart for Buy Now, live pins, auctions, and flash sales.
      </p>

      <div className="mt-8 space-y-4">
        {!lines.length && (
          <div className="rounded-2xl border border-dashed border-hubsom-forest/20 bg-white/50 px-6 py-12 text-center">
            <p className="text-hubsom-ink/60">Your cart is empty.</p>
            <Link
              href="/marketplace"
              className="mt-4 inline-block text-sm font-semibold text-hubsom-leaf"
            >
              Browse marketplace
            </Link>
          </div>
        )}

        {lines.map((line) =>
          line ? (
            <div
              key={line.product.id}
              className="flex flex-wrap items-center justify-between gap-4 rounded-2xl border border-hubsom-forest/10 bg-white/70 p-4"
            >
              <div>
                <p className="font-semibold text-hubsom-ink">{line.product.name}</p>
                <p className="text-xs text-hubsom-ink/55">
                  {line.item.source} · {formatGhs(line.unit)}
                </p>
              </div>
              <div className="flex items-center gap-3">
                <button
                  type="button"
                  className="h-8 w-8 rounded-lg border border-hubsom-forest/15"
                  onClick={() =>
                    setQuantity(line.product.id, line.item.quantity - 1)
                  }
                >
                  −
                </button>
                <span className="w-6 text-center font-semibold">
                  {line.item.quantity}
                </span>
                <button
                  type="button"
                  className="h-8 w-8 rounded-lg border border-hubsom-forest/15"
                  onClick={() =>
                    setQuantity(line.product.id, line.item.quantity + 1)
                  }
                >
                  +
                </button>
                <p className="w-24 text-right font-bold text-hubsom-forest">
                  {formatGhs(line.total)}
                </p>
                <button
                  type="button"
                  onClick={() => removeItem(line.product.id)}
                  className="text-xs text-hubsom-live"
                >
                  Remove
                </button>
              </div>
            </div>
          ) : null,
        )}
      </div>

      {!!lines.length && (
        <div className="mt-8 rounded-2xl border border-hubsom-forest/10 bg-white/70 p-5">
          <div className="flex items-center justify-between">
            <span className="text-hubsom-ink/65">Subtotal</span>
            <span className="text-xl font-bold text-hubsom-forest">
              {formatGhs(subtotal)}
            </span>
          </div>
          <button
            type="button"
            disabled={loading}
            onClick={checkout}
            className="mt-4 w-full rounded-xl bg-hubsom-forest py-3 text-sm font-bold text-white disabled:opacity-60"
          >
            {loading ? "Processing…" : "Checkout with Hubsom Pay"}
          </button>
        </div>
      )}

      {status && (
        <p className="mt-4 text-center text-sm font-medium text-hubsom-leaf">
          {status}
        </p>
      )}
    </div>
  );
}

"use client";

import { useState } from "react";
import { X } from "lucide-react";
import { formatGhs } from "@/lib/currency";
import { getEffectivePrice, getProduct } from "@/lib/data/products";
import { useCartStore } from "@/lib/stores/cart";

export function LiveCartDrawer({
  streamId,
  open,
  onClose,
}: {
  streamId: string;
  open: boolean;
  onClose: () => void;
}) {
  const items = useCartStore((s) => s.items);
  const clear = useCartStore((s) => s.clear);
  const [status, setStatus] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  if (!open) return null;

  const lines = items
    .map((item) => {
      const product = getProduct(item.productId);
      if (!product) return null;
      const unit = getEffectivePrice(product);
      return { item, product, unit, total: unit * item.quantity };
    })
    .filter(Boolean);

  const subtotal = lines.reduce((sum, l) => sum + (l?.total ?? 0), 0);

  async function oneTapCheckout() {
    setLoading(true);
    setStatus(null);
    try {
      const res = await fetch("/api/checkout", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          oneTap: true,
          streamId,
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
      for (const item of items) {
        await fetch("/api/inventory/sync", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            productId: item.productId,
            delta: -item.quantity,
            streamId,
          }),
        });
      }
      clear();
      setStatus(`Order ${data.orderId} confirmed · ${formatGhs(data.subtotalGhs)}`);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="fixed inset-0 z-[70] flex justify-end bg-black/50 p-3 sm:p-6">
      <div className="flex w-full max-w-md flex-col rounded-2xl border border-white/15 bg-hubsom-night text-white shadow-2xl">
        <div className="flex items-center justify-between border-b border-white/10 px-4 py-3">
          <h3 className="font-display text-xl font-semibold">Live cart</h3>
          <button type="button" onClick={onClose} aria-label="Close cart">
            <X className="h-5 w-5" />
          </button>
        </div>
        <div className="flex-1 space-y-3 overflow-y-auto px-4 py-4">
          {!lines.length && (
            <p className="text-sm text-white/60">
              Pin products while watching, then one-tap checkout.
            </p>
          )}
          {lines.map((line) =>
            line ? (
              <div
                key={line.product.id}
                className="flex items-start justify-between gap-3 rounded-xl bg-white/5 px-3 py-3"
              >
                <div>
                  <p className="font-semibold">{line.product.name}</p>
                  <p className="text-xs text-white/55">
                    Qty {line.item.quantity} · {line.item.source}
                  </p>
                </div>
                <p className="font-bold text-hubsom-sun">{formatGhs(line.total)}</p>
              </div>
            ) : null,
          )}
        </div>
        <div className="border-t border-white/10 p-4">
          <div className="mb-3 flex items-center justify-between text-sm">
            <span className="text-white/60">Subtotal</span>
            <span className="font-bold">{formatGhs(subtotal)}</span>
          </div>
          <button
            type="button"
            disabled={!items.length || loading}
            onClick={oneTapCheckout}
            className="w-full rounded-xl bg-hubsom-gold py-3 text-sm font-bold text-hubsom-ink disabled:opacity-50"
          >
            {loading ? "Processing…" : "One-tap checkout"}
          </button>
          {status && <p className="mt-2 text-center text-xs text-hubsom-mint">{status}</p>}
        </div>
      </div>
    </div>
  );
}

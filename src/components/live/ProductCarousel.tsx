"use client";

import Image from "next/image";
import { X } from "lucide-react";
import { SaveProductButton } from "@/components/product/SaveProductButton";
import { formatGhs } from "@/lib/currency";
import { getEffectivePrice } from "@/lib/pricing";
import { categoryName } from "@/lib/categories";
import type { Product } from "@/types";

/** TikTok Shop–style bag sheet — only opens on demand, never overlays the host face. */
export function ProductCarousel({
  products,
  pinnedProductId,
  onPin,
  onBuy,
  onClose,
  savedProductIds = [],
}: {
  products: Product[];
  pinnedProductId?: string;
  onPin: (productId: string) => void;
  onBuy: (product: Product) => void;
  onClose?: () => void;
  savedProductIds?: string[];
}) {
  const savedSet = new Set(savedProductIds);

  return (
    <div className="max-h-[48svh] rounded-t-3xl border-t border-white/10 bg-hubsom-night/95 text-white backdrop-blur-xl">
      <div className="flex items-center justify-between px-4 pb-2 pt-3">
        <div>
          <p className="text-sm font-bold">Shopping bag</p>
          <p className="text-[11px] text-white/55">{products.length} items</p>
        </div>
        {onClose && (
          <button
            type="button"
            onClick={onClose}
            className="inline-flex h-8 w-8 items-center justify-center rounded-full bg-white/10"
            aria-label="Close bag"
          >
            <X className="h-4 w-4" />
          </button>
        )}
      </div>
      <div className="scrollbar-thin max-h-[calc(48svh-3.5rem)] space-y-2 overflow-y-auto px-3 pb-5">
        {products.map((product) => {
          const pinned = product.id === pinnedProductId;
          return (
            <div
              key={product.id}
              className={`flex items-center gap-2.5 rounded-2xl border px-2 py-2 ${
                pinned
                  ? "border-hubsom-gold/70 bg-hubsom-gold/10"
                  : "border-white/10 bg-white/5"
              }`}
            >
              <div className="relative h-14 w-14 shrink-0 overflow-hidden rounded-xl">
                <Image
                  src={product.images[0]}
                  alt={product.name}
                  fill
                  className="object-cover"
                  sizes="56px"
                />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-[9px] font-semibold uppercase tracking-[0.12em] text-white/45">
                  {categoryName(product.category)}
                </p>
                <p className="truncate text-xs font-semibold leading-snug">
                  {product.name}
                </p>
                <p className="text-xs font-bold text-hubsom-sun">
                  {formatGhs(getEffectivePrice(product))}
                </p>
              </div>
              <div className="flex shrink-0 flex-col items-end gap-1">
                <SaveProductButton
                  productId={product.id}
                  initialSaved={savedSet.has(product.id)}
                  size="icon"
                  variant="live"
                />
                <button
                  type="button"
                  onClick={() => onPin(product.id)}
                  className="rounded-lg border border-white/15 px-2.5 py-1 text-[10px] font-semibold"
                >
                  {pinned ? "Pinned" : "Pin"}
                </button>
                <button
                  type="button"
                  onClick={() => onBuy(product)}
                  className="rounded-lg bg-hubsom-live px-2.5 py-1 text-[10px] font-bold text-white"
                >
                  Buy
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

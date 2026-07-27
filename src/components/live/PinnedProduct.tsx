"use client";

import Image from "next/image";
import { ShoppingBag } from "lucide-react";
import { formatGhs } from "@/lib/currency";
import { getEffectivePrice } from "@/lib/data/products";
import type { Product } from "@/types";

/** Compact TikTok-Shop-style product bag — sits at the bottom edge, never covers the face. */
export function PinnedProduct({
  product,
  onBuy,
  onOpenShop,
}: {
  product: Product;
  onBuy: () => void;
  onOpenShop?: () => void;
}) {
  return (
    <div className="flex max-w-[92%] items-center gap-2 rounded-2xl border border-white/20 bg-black/55 py-1.5 pl-1.5 pr-2 text-white shadow-lg backdrop-blur-md">
      <button
        type="button"
        onClick={onOpenShop}
        className="relative h-11 w-11 shrink-0 overflow-hidden rounded-xl"
        aria-label="Open bag"
      >
        <Image
          src={product.images[0]}
          alt={product.name}
          fill
          className="object-cover"
          sizes="44px"
        />
      </button>
      <button
        type="button"
        onClick={onOpenShop}
        className="min-w-0 flex-1 text-left"
      >
        <p className="truncate text-xs font-semibold leading-tight">{product.name}</p>
        <p className="text-xs font-bold text-hubsom-sun">
          {formatGhs(getEffectivePrice(product))}
        </p>
      </button>
      <button
        type="button"
        onClick={onBuy}
        className="inline-flex shrink-0 items-center gap-1 rounded-xl bg-hubsom-live px-3 py-2 text-[11px] font-bold text-white"
      >
        <ShoppingBag className="h-3.5 w-3.5" />
        Buy
      </button>
    </div>
  );
}

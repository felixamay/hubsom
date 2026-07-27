"use client";

import Image from "next/image";
import { ShoppingBag } from "lucide-react";
import { formatGhs } from "@/lib/currency";
import { getEffectivePrice } from "@/lib/data/products";
import { categoryName } from "@/lib/categories";
import type { Product } from "@/types";

export function PinnedProduct({
  product,
  onBuy,
}: {
  product: Product;
  onBuy: () => void;
}) {
  return (
    <div className="flex items-center gap-3 rounded-2xl border border-hubsom-gold/50 bg-black/55 p-3 text-white backdrop-blur-md">
      <div className="relative h-16 w-16 overflow-hidden rounded-xl">
        <Image
          src={product.images[0]}
          alt={product.name}
          fill
          className="object-cover"
          sizes="64px"
        />
      </div>
      <div className="min-w-0 flex-1">
        <p className="text-[10px] font-bold uppercase tracking-[0.16em] text-hubsom-gold">
          Pinned · {categoryName(product.category)}
        </p>
        <p className="truncate font-semibold">{product.name}</p>
        <p className="text-sm font-bold text-hubsom-sun">
          {formatGhs(getEffectivePrice(product))}
        </p>
      </div>
      <button
        type="button"
        onClick={onBuy}
        className="inline-flex items-center gap-1 rounded-xl bg-hubsom-gold px-3 py-2 text-xs font-bold text-hubsom-ink"
      >
        <ShoppingBag className="h-3.5 w-3.5" />
        Tap buy
      </button>
    </div>
  );
}

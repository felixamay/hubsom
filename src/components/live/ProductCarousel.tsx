"use client";

import Image from "next/image";
import { formatGhs } from "@/lib/currency";
import { getEffectivePrice } from "@/lib/data/products";
import { categoryName } from "@/lib/categories";
import type { Product } from "@/types";

export function ProductCarousel({
  products,
  pinnedProductId,
  onPin,
  onBuy,
}: {
  products: Product[];
  pinnedProductId?: string;
  onPin: (productId: string) => void;
  onBuy: (product: Product) => void;
}) {
  return (
    <div className="scrollbar-thin flex gap-3 overflow-x-auto pb-1">
      {products.map((product) => {
        const pinned = product.id === pinnedProductId;
        return (
          <div
            key={product.id}
            className={`min-w-[220px] max-w-[220px] rounded-2xl border p-3 backdrop-blur ${
              pinned
                ? "border-hubsom-gold bg-hubsom-gold/15"
                : "border-white/15 bg-black/40"
            }`}
          >
            <div className="relative mb-2 aspect-[16/10] overflow-hidden rounded-xl">
              <Image
                src={product.images[0]}
                alt={product.name}
                fill
                className="object-cover"
                sizes="220px"
              />
            </div>
            <p className="text-[10px] font-semibold uppercase tracking-[0.14em] text-hubsom-gold">
              {categoryName(product.category)}
            </p>
            <p className="mt-1 line-clamp-2 text-sm font-semibold text-white">
              {product.name}
            </p>
            <p className="mt-1 text-sm font-bold text-hubsom-sun">
              {formatGhs(getEffectivePrice(product))}
            </p>
            <div className="mt-3 flex gap-2">
              <button
                type="button"
                onClick={() => onPin(product.id)}
                className="flex-1 rounded-lg border border-white/20 px-2 py-1.5 text-xs font-semibold text-white hover:bg-white/10"
              >
                {pinned ? "Pinned" : "Pin"}
              </button>
              <button
                type="button"
                onClick={() => onBuy(product)}
                className="flex-1 rounded-lg bg-hubsom-leaf px-2 py-1.5 text-xs font-bold text-white hover:brightness-110"
              >
                Buy
              </button>
            </div>
          </div>
        );
      })}
    </div>
  );
}

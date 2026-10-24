"use client";

import { useState } from "react";
import { getEffectivePrice } from "@/lib/pricing";
import { useCartStore } from "@/lib/stores/cart";
import type { Product } from "@/types";

export function AddToCartButton({ product }: { product: Product }) {
  const addItem = useCartStore((s) => s.addItem);
  const [added, setAdded] = useState(false);

  function add() {
    addItem({
      productId: product.id,
      quantity: 1,
      source: "buy-now",
      name: product.name,
      priceGhs: getEffectivePrice(product),
      image: product.images[0],
      category: product.category,
    });
    setAdded(true);
    window.setTimeout(() => setAdded(false), 1600);
  }

  return (
    <button
      type="button"
      onClick={add}
      className="rounded-xl bg-hubsom-forest px-5 py-3 text-sm font-bold text-white"
    >
      {added ? "Added" : "Add to cart"}
    </button>
  );
}

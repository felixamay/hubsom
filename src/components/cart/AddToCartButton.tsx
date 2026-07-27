"use client";

import { useState } from "react";
import { useCartStore } from "@/lib/stores/cart";

export function AddToCartButton({ productId }: { productId: string }) {
  const addItem = useCartStore((s) => s.addItem);
  const [done, setDone] = useState(false);

  return (
    <button
      type="button"
      onClick={() => {
        addItem({ productId, quantity: 1, source: "buy-now" });
        setDone(true);
      }}
      className="rounded-xl bg-hubsom-forest px-6 py-3 text-sm font-bold text-white transition hover:bg-hubsom-leaf"
    >
      {done ? "Added to cart" : "Buy Now · Add to cart"}
    </button>
  );
}

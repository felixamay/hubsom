import type { Product } from "@/types";

export function getEffectivePrice(product: Pick<Product, "priceGhs" | "flashSale">): number {
  if (!product.flashSale) return product.priceGhs;
  return Math.round(product.priceGhs * (1 - product.flashSale.discountPct / 100));
}

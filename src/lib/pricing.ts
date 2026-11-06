import type { Product } from "@/types";

/** True while a listing's flash sale window is still open. */
export function isFlashSaleActive(
  flashSale: Product["flashSale"] | null | undefined,
  now = Date.now(),
): boolean {
  if (!flashSale) return false;
  const endsAt = Date.parse(flashSale.endsAt);
  if (!Number.isFinite(endsAt) || endsAt <= now) return false;
  const pct = Number(flashSale.discountPct);
  return Number.isFinite(pct) && pct > 0;
}

export function getEffectivePrice(
  product: Pick<Product, "priceGhs" | "flashSale">,
  now = Date.now(),
): number {
  const base = Number(product.priceGhs);
  const price = Number.isFinite(base) ? base : 0;
  if (!isFlashSaleActive(product.flashSale, now)) return price;
  const pct = Math.min(100, Math.max(0, Number(product.flashSale!.discountPct)));
  return Math.max(0, Math.round(price * (1 - pct / 100)));
}

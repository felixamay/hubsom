/**
 * Split cart rows of the same SKU share one stock pool.
 * Checking each row against the listing's full stock would let
 * [{ productId: "x", quantity: 1 }, { productId: "x", quantity: 1 }]
 * buy two units of a 1-unit listing.
 */
export function allocateCatalogStock(
  items: Array<{ productId: string; quantity: number }>,
  stockByProduct: ReadonlyMap<string, number>,
):
  | { ok: true; consumed: Map<string, number> }
  | { ok: false; productId: string } {
  const remaining = new Map(stockByProduct);
  const consumed = new Map<string, number>();

  for (const item of items) {
    const quantity = item.quantity;
    if (!Number.isFinite(quantity) || quantity < 1) {
      return { ok: false, productId: item.productId };
    }
    const left = remaining.get(item.productId);
    if (left == null || left < quantity) {
      return { ok: false, productId: item.productId };
    }
    remaining.set(item.productId, left - quantity);
    consumed.set(
      item.productId,
      (consumed.get(item.productId) ?? 0) + quantity,
    );
  }

  return { ok: true, consumed };
}

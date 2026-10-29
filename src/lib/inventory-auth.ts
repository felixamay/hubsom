/**
 * Guardrails for catalog stock mutations. Any signed-in caller used to be
 * able to POST /api/inventory/sync against someone else's listing.
 */

export function parseStockDelta(
  value: unknown,
  fallback = -1,
): number | undefined {
  const raw = value === undefined || value === null ? fallback : value;
  const n = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isFinite(n) || !Number.isInteger(n)) return undefined;
  return n;
}

export function userOwnsProduct(input: {
  userId?: string | null;
  userSellerId?: string | null;
  productSellerId: string;
  sellerOwnerUserId?: string | null;
}): boolean {
  const userId = input.userId?.trim();
  if (!userId) return false;
  if (
    input.userSellerId &&
    input.userSellerId === input.productSellerId
  ) {
    return true;
  }
  if (
    input.sellerOwnerUserId &&
    input.sellerOwnerUserId === userId
  ) {
    return true;
  }
  return false;
}

/**
 * Checkout quantities must be whole units of at least 1.
 * Missing, negative, fractional, or non-finite values must not reach stock math —
 * `adjustProductStock(-quantity)` would otherwise *increase* stock, and
 * `JSON.stringify` persists `NaN` as `null`, which bricks the listing.
 */
export function parseCheckoutQuantity(value: unknown): number | null {
  if (typeof value === "number") {
    return Number.isSafeInteger(value) && value >= 1 ? value : null;
  }
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    return Number.isSafeInteger(parsed) && parsed >= 1 ? parsed : null;
  }
  return null;
}

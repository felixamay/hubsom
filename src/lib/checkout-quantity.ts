/** Positive integer line quantity. Rejects negatives that would inflate stock. */
export function parseLineQuantity(raw: unknown): number | null {
  const n = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isInteger(n) || n < 1 || n > 1000) return null;
  return n;
}

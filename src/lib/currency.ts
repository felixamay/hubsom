const formatter = new Intl.NumberFormat("en-GH", {
  style: "currency",
  currency: "GHS",
  maximumFractionDigits: 2,
});

export function formatGhs(amount: number): string {
  return formatter.format(amount);
}

export function formatCompactGhs(amount: number): string {
  if (amount >= 1_000_000) return `GHS ${(amount / 1_000_000).toFixed(1)}M`;
  if (amount >= 1_000) return `GHS ${(amount / 1_000).toFixed(1)}K`;
  return formatGhs(amount);
}

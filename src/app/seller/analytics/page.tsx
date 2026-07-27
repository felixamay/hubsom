import type { Metadata } from "next";
import { formatCompactGhs, formatGhs } from "@/lib/currency";
import { SELLER_ANALYTICS, VIEWER_ANALYTICS } from "@/lib/data/streams";

export const metadata: Metadata = {
  title: "Seller analytics",
};

export default function SellerAnalyticsPage() {
  const seller = SELLER_ANALYTICS[0];
  const viewer = VIEWER_ANALYTICS[0];

  const cards = [
    { label: "Revenue", value: formatCompactGhs(seller.revenueGhs) },
    { label: "Units sold", value: seller.unitsSold.toLocaleString() },
    { label: "Unique buyers", value: seller.uniqueBuyers.toLocaleString() },
    { label: "Peak concurrent", value: seller.peakConcurrent.toLocaleString() },
    { label: "Avg latency", value: `${seller.avgLatencyMs} ms` },
    {
      label: "Inventory sync events",
      value: seller.inventorySyncEvents.toLocaleString(),
    },
    { label: "Chat messages", value: viewer.chatMessages.toLocaleString() },
    { label: "Reactions", value: viewer.reactions.toLocaleString() },
    {
      label: "Conversion rate",
      value: `${(viewer.conversionRate * 100).toFixed(1)}%`,
    },
    {
      label: "Avg watch time",
      value: `${Math.round(viewer.avgWatchSeconds / 60)} min`,
    },
  ];

  return (
    <div className="mx-auto max-w-6xl px-4 py-10 sm:px-6">
      <h1 className="font-display text-4xl font-extrabold text-hubsom-forest">
        Seller analytics
      </h1>
      <p className="mt-3 max-w-2xl text-hubsom-ink/70">
        Performance for Makola Mix Live — mixed categories, one funnel. Push
        notification hooks and auto-scale metrics included.
      </p>

      <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {cards.map((card) => (
          <div
            key={card.label}
            className="rounded-3xl border border-hubsom-forest/10 bg-white/70 p-5"
          >
            <p className="text-xs font-bold uppercase tracking-[0.16em] text-hubsom-leaf">
              {card.label}
            </p>
            <p className="mt-3 font-display text-3xl font-bold text-hubsom-forest">
              {card.value}
            </p>
          </div>
        ))}
      </div>

      <div className="mt-8 rounded-3xl border border-hubsom-forest/10 bg-hubsom-forest p-6 text-hubsom-mint">
        <p className="font-display text-2xl font-bold text-white">
          Scale posture
        </p>
        <p className="mt-2 max-w-2xl text-sm leading-relaxed text-hubsom-mint/85">
          Hubsom&apos;s Agora live layer targets sub-2s latency with adaptive bitrate
          and horizontal fan-out for 10,000+ concurrent viewers. Gross merchandise for
          this show: {formatGhs(seller.revenueGhs)}.
        </p>
      </div>
    </div>
  );
}

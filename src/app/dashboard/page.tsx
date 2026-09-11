import type { Metadata } from "next";
import Link from "next/link";
import { EmptyState } from "@/components/ui/EmptyState";
import { formatCompactGhs, formatGhs } from "@/lib/currency";
import { getPlatformAnalytics } from "@/lib/data/analytics";
import { listAllStreams } from "@/lib/data/stream-registry";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Dashboard",
};

export default async function DashboardPage() {
  const [{ seller, viewer }, streams] = await Promise.all([
    getPlatformAnalytics(),
    listAllStreams(),
  ]);
  const live = streams.filter((s) => s.status === "live");

  const cards = [
    { label: "Revenue", value: formatCompactGhs(seller.revenueGhs) },
    { label: "Units sold", value: seller.unitsSold.toLocaleString() },
    { label: "Buyers", value: seller.uniqueBuyers.toLocaleString() },
    { label: "Peak viewers", value: seller.peakConcurrent.toLocaleString() },
    { label: "Latency", value: `${seller.avgLatencyMs} ms` },
    {
      label: "Conversion",
      value: `${(viewer.conversionRate * 100).toFixed(1)}%`,
    },
  ];

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
            Dashboard
          </h1>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Live commerce performance from real orders and shows.
          </p>
        </div>
        <Link
          href="/seller/analytics"
          className="text-xs font-bold text-hubsom-cyan"
        >
          Details
        </Link>
      </div>

      <div className="mt-5 grid grid-cols-2 gap-3">
        {cards.map((card) => (
          <div
            key={card.label}
            className="rounded-2xl border border-hubsom-forest/10 bg-white/80 p-4"
          >
            <p className="text-[10px] font-bold uppercase tracking-[0.14em] text-hubsom-ink/45">
              {card.label}
            </p>
            <p className="mt-2 font-display text-2xl font-bold text-hubsom-forest">
              {card.value}
            </p>
          </div>
        ))}
      </div>

      <div className="mt-5 rounded-2xl bg-hubsom-night p-5 text-white">
        <p className="text-xs font-bold uppercase tracking-[0.16em] text-hubsom-gold">
          Gross merchandise
        </p>
        <p className="mt-2 font-display text-3xl font-bold">
          {formatGhs(seller.revenueGhs)}
        </p>
        <p className="mt-2 text-sm text-white/65">
          From confirmed checkout volume · inventory sync{" "}
          {seller.inventorySyncEvents.toLocaleString()} events
        </p>
      </div>

      <div className="mt-5">
        <h2 className="font-display text-xl font-bold text-hubsom-ink">Live now</h2>
        <div className="mt-3 space-y-2">
          {!live.length && (
            <EmptyState
              title="Nothing live"
              body="Start a show to see live metrics here."
              actionHref="/seller/go-live"
              actionLabel="Go live"
            />
          )}
          {live.map((stream) => (
            <Link
              key={stream.id}
              href={`/live/${stream.id}`}
              className="flex items-center justify-between rounded-2xl border border-hubsom-forest/10 bg-white/80 px-4 py-3"
            >
              <span className="min-w-0">
                <span className="block truncate text-sm font-semibold text-hubsom-ink">
                  {stream.title}
                </span>
                <span className="text-xs text-hubsom-ink/55">
                  {stream.viewerCount.toLocaleString()} watching
                </span>
              </span>
              <span className="rounded-md bg-hubsom-live px-2 py-1 text-[10px] font-bold uppercase text-white">
                Live
              </span>
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}

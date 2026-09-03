import type { Metadata } from "next";
import Link from "next/link";
import { formatGhs } from "@/lib/currency";
import { getPlatformAnalytics } from "@/lib/data/analytics";
import { EmptyState } from "@/components/ui/EmptyState";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Seller analytics",
};

export default async function SellerAnalyticsPage() {
  const { seller, viewer } = await getPlatformAnalytics();
  const empty = seller.revenueGhs === 0 && seller.unitsSold === 0;

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
        Analytics
      </h1>
      <p className="mt-2 text-sm text-hubsom-ink/65">
        Revenue, conversion, and viewer metrics from real Hubsom activity.
      </p>

      {empty ? (
        <div className="mt-5">
          <EmptyState
            title="No sales data yet"
            body="Go live and complete checkouts to populate analytics."
            actionHref="/seller/go-live"
            actionLabel="Go live"
          />
        </div>
      ) : (
        <div className="mt-5 space-y-3">
          <div className="rounded-2xl border border-hubsom-forest/10 bg-white/80 p-4">
            <p className="text-xs font-bold uppercase tracking-[0.14em] text-hubsom-ink/45">
              Revenue
            </p>
            <p className="mt-2 font-display text-3xl font-bold text-hubsom-forest">
              {formatGhs(seller.revenueGhs)}
            </p>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="rounded-2xl border border-hubsom-forest/10 bg-white/80 p-4">
              <p className="text-[10px] font-bold uppercase text-hubsom-ink/45">
                Units
              </p>
              <p className="mt-2 text-xl font-bold">{seller.unitsSold}</p>
            </div>
            <div className="rounded-2xl border border-hubsom-forest/10 bg-white/80 p-4">
              <p className="text-[10px] font-bold uppercase text-hubsom-ink/45">
                Conversion
              </p>
              <p className="mt-2 text-xl font-bold">
                {(viewer.conversionRate * 100).toFixed(1)}%
              </p>
            </div>
          </div>
        </div>
      )}

      <Link
        href="/dashboard"
        className="mt-6 inline-block text-sm font-bold text-hubsom-cyan"
      >
        Back to dashboard
      </Link>
    </div>
  );
}

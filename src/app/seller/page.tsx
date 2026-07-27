import type { Metadata } from "next";
import Link from "next/link";
import { BarChart3, Radio, Store } from "lucide-react";

export const metadata: Metadata = {
  title: "Seller hub",
  description: "Go live, manage inventory, and track Hubsom commerce analytics.",
};

export default function SellerHubPage() {
  return (
    <div className="mx-auto max-w-5xl px-4 py-12 sm:px-6">
      <h1 className="font-display text-4xl font-extrabold text-hubsom-forest">
        Seller hub
      </h1>
      <p className="mt-3 max-w-2xl text-hubsom-ink/70">
        Run mixed-category live shows from Ghana — pin produce next to phones, open
        auctions, sync inventory, and review performance.
      </p>

      <div className="mt-10 grid gap-4 md:grid-cols-3">
        <Link
          href="/seller/go-live"
          className="rounded-3xl border border-hubsom-forest/10 bg-white/70 p-6 transition hover:border-hubsom-leaf"
        >
          <Radio className="h-6 w-6 text-hubsom-live" />
          <h2 className="mt-4 font-display text-2xl font-bold text-hubsom-forest">
            Go live
          </h2>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Launch Agora multi-host commerce with pinning, auctions, and recording.
          </p>
        </Link>
        <Link
          href="/seller/analytics"
          className="rounded-3xl border border-hubsom-forest/10 bg-white/70 p-6 transition hover:border-hubsom-leaf"
        >
          <BarChart3 className="h-6 w-6 text-hubsom-leaf" />
          <h2 className="mt-4 font-display text-2xl font-bold text-hubsom-forest">
            Analytics
          </h2>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Viewer and seller metrics, conversion, latency, inventory sync events.
          </p>
        </Link>
        <Link
          href="/stores/ama-market-live"
          className="rounded-3xl border border-hubsom-forest/10 bg-white/70 p-6 transition hover:border-hubsom-leaf"
        >
          <Store className="h-6 w-6 text-hubsom-gold" />
          <h2 className="mt-4 font-display text-2xl font-bold text-hubsom-forest">
            Storefront
          </h2>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Preview a Ghana seller store with live + Buy Now inventory.
          </p>
        </Link>
      </div>
    </div>
  );
}

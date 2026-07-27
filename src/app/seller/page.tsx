import type { Metadata } from "next";
import Link from "next/link";
import { BarChart3, PackagePlus, Radio, Store } from "lucide-react";
import { ensureDefaultSeller } from "@/lib/data/sellers";
import { getProductsBySeller } from "@/lib/data/products";
import { getStreamsBySeller } from "@/lib/data/streams";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Seller hub",
  description: "Go live, manage inventory, and track Hubsom commerce analytics.",
};

export default async function SellerHubPage() {
  const seller = await ensureDefaultSeller();
  const [products, streams] = await Promise.all([
    getProductsBySeller(seller.id),
    getStreamsBySeller(seller.id),
  ]);

  return (
    <div className="mx-auto max-w-5xl px-4 py-12 sm:px-6">
      <h1 className="font-display text-4xl font-extrabold text-hubsom-forest">
        Seller hub
      </h1>
      <p className="mt-3 max-w-2xl text-hubsom-ink/70">
        Manage your catalog, go live, and track performance. Store:{" "}
        <Link
          href={`/stores/${seller.slug}`}
          className="font-semibold text-hubsom-cyan"
        >
          {seller.name}
        </Link>
      </p>

      <div className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div className="rounded-2xl border border-hubsom-forest/10 bg-white/70 p-4">
          <p className="text-[10px] font-bold uppercase text-hubsom-ink/45">
            Products
          </p>
          <p className="mt-1 font-display text-2xl font-bold">{products.length}</p>
        </div>
        <div className="rounded-2xl border border-hubsom-forest/10 bg-white/70 p-4">
          <p className="text-[10px] font-bold uppercase text-hubsom-ink/45">
            Shows
          </p>
          <p className="mt-1 font-display text-2xl font-bold">{streams.length}</p>
        </div>
      </div>

      <div className="mt-10 grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Link
          href="/seller/go-live"
          className="rounded-3xl border border-hubsom-forest/10 bg-white/70 p-6 transition hover:border-hubsom-leaf"
        >
          <Radio className="h-6 w-6 text-hubsom-live" />
          <h2 className="mt-4 font-display text-2xl font-bold text-hubsom-forest">
            Go live
          </h2>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Launch Agora live commerce with pinning and checkout.
          </p>
        </Link>
        <Link
          href="/seller/products/new"
          className="rounded-3xl border border-hubsom-forest/10 bg-white/70 p-6 transition hover:border-hubsom-leaf"
        >
          <PackagePlus className="h-6 w-6 text-hubsom-gold" />
          <h2 className="mt-4 font-display text-2xl font-bold text-hubsom-forest">
            Add product
          </h2>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Publish catalog items for Buy Now and live shows.
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
            Revenue, conversion, latency, and inventory sync.
          </p>
        </Link>
        <Link
          href={`/stores/${seller.slug}`}
          className="rounded-3xl border border-hubsom-forest/10 bg-white/70 p-6 transition hover:border-hubsom-leaf"
        >
          <Store className="h-6 w-6 text-hubsom-cyan" />
          <h2 className="mt-4 font-display text-2xl font-bold text-hubsom-forest">
            Storefront
          </h2>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Preview your public store with live + Buy Now inventory.
          </p>
        </Link>
      </div>
    </div>
  );
}

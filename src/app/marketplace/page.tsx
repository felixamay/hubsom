import type { Metadata } from "next";
import Link from "next/link";
import { ProductGrid } from "@/components/marketplace/ProductGrid";
import { CATEGORIES } from "@/lib/categories";
import { PRODUCTS } from "@/lib/data/products";

export const metadata: Metadata = {
  title: "Marketplace",
  description: "Buy Now across every Hubsom category in Ghana Cedis.",
};

export default function MarketplacePage() {
  return (
    <div className="mx-auto max-w-7xl px-4 py-10 sm:px-6">
      <h1 className="font-display text-4xl font-extrabold text-hubsom-forest sm:text-5xl">
        Marketplace
      </h1>
      <p className="mt-3 max-w-2xl text-hubsom-ink/70">
        One catalog for Buy Now, live selling, auctions, flash sales, bundles, and
        store listings. Groceries are a category — not a separate app.
      </p>

      <div className="scrollbar-thin mt-8 flex gap-2 overflow-x-auto pb-2">
        <Link
          href="/marketplace"
          className="shrink-0 rounded-xl bg-hubsom-forest px-4 py-2 text-sm font-semibold text-white"
        >
          All
        </Link>
        {CATEGORIES.map((c) => (
          <Link
            key={c.slug}
            href={`/categories/${c.slug}`}
            className="shrink-0 rounded-xl border border-hubsom-forest/10 bg-white/70 px-4 py-2 text-sm font-semibold text-hubsom-forest"
          >
            {c.name}
          </Link>
        ))}
      </div>

      <div className="mt-8">
        <ProductGrid products={PRODUCTS} />
      </div>
    </div>
  );
}

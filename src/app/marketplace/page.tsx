import type { Metadata } from "next";
import Link from "next/link";
import { ProductGrid } from "@/components/marketplace/ProductGrid";
import { EmptyState } from "@/components/ui/EmptyState";
import { CATEGORIES } from "@/lib/categories";
import { listProducts } from "@/lib/data/products";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Marketplace",
};

export default async function MarketplacePage() {
  const products = await listProducts();

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
            Marketplace
          </h1>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Buy Now across every Hubsom category.
          </p>
        </div>
        <Link
          href="/seller/products/new"
          className="rounded-xl bg-hubsom-forest px-3 py-2 text-xs font-bold text-white"
        >
          Add product
        </Link>
      </div>

      <div className="scrollbar-thin mt-4 flex gap-2 overflow-x-auto pb-1">
        {CATEGORIES.slice(0, 12).map((cat) => (
          <Link
            key={cat.slug}
            href={`/categories/${cat.slug}`}
            className="shrink-0 rounded-full border border-hubsom-forest/15 bg-white/80 px-3 py-1.5 text-xs font-semibold text-hubsom-ink"
          >
            {cat.name}
          </Link>
        ))}
      </div>

      <div className="mt-5">
        {products.length ? (
          <ProductGrid products={products} />
        ) : (
          <EmptyState
            title="Marketplace is empty"
            body="List your first product to appear here."
            actionHref="/seller/products/new"
            actionLabel="Add product"
          />
        )}
      </div>
    </div>
  );
}

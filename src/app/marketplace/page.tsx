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

export default async function MarketplacePage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  const { q } = await searchParams;
  const query = (q ?? "").trim().toLowerCase();
  const products = await listProducts();
  const filtered = query
    ? products.filter((p) => {
        const haystack = [
          p.name,
          p.description,
          p.category,
          ...(p.tags ?? []),
        ]
          .join(" ")
          .toLowerCase();
        return haystack.includes(query);
      })
    : products;

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
            {query ? "Search results" : "Marketplace"}
          </h1>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            {query
              ? `${filtered.length} result${filtered.length === 1 ? "" : "s"} for “${q}”`
              : "Buy Now across every Hubsom category."}
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
        {filtered.length ? (
          <ProductGrid products={filtered} />
        ) : (
          <EmptyState
            title={query ? "No matches" : "Marketplace is empty"}
            body={
              query
                ? "Try another search or browse categories."
                : "List your first product to appear here."
            }
            actionHref={query ? "/categories" : "/seller/products/new"}
            actionLabel={query ? "Browse categories" : "Add product"}
          />
        )}
      </div>
    </div>
  );
}

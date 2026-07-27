import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ProductGrid } from "@/components/marketplace/ProductGrid";
import { CATEGORY_MAP } from "@/lib/categories";
import { getProductsByCategory } from "@/lib/data/products";
import type { ProductCategory } from "@/types";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const meta = CATEGORY_MAP[slug as ProductCategory];
  return {
    title: meta?.name ?? "Category",
    description: meta?.description,
  };
}

export default async function CategoryPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const meta = CATEGORY_MAP[slug as ProductCategory];
  if (!meta) notFound();

  const products = getProductsByCategory(slug);

  return (
    <div className="mx-auto max-w-7xl px-4 py-10 sm:px-6">
      <h1 className="font-display text-4xl font-extrabold text-hubsom-forest">
        {meta.name}
      </h1>
      <p className="mt-3 max-w-2xl text-hubsom-ink/70">{meta.description}</p>
      <p className="mt-2 text-sm font-medium text-hubsom-leaf">
        Available via Buy Now · Live · Auctions · Flash · Bundles · Stores · Promos
      </p>
      <div className="mt-8">
        <ProductGrid products={products} />
      </div>
    </div>
  );
}

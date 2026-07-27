import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ProductGrid } from "@/components/marketplace/ProductGrid";
import { EmptyState } from "@/components/ui/EmptyState";
import { auth } from "@/auth";
import { CATEGORY_MAP } from "@/lib/categories";
import { getProductsByCategory } from "@/lib/data/products";
import { getUserById } from "@/lib/data/users";
import type { ProductCategory } from "@/types";

export const dynamic = "force-dynamic";

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

  const [products, session] = await Promise.all([
    getProductsByCategory(slug),
    auth(),
  ]);
  const user = session?.user?.id
    ? await getUserById(session.user.id)
    : undefined;

  return (
    <div className="mx-auto max-w-7xl px-4 py-10 sm:px-6">
      <h1 className="font-display text-4xl font-extrabold text-hubsom-forest">
        {meta.name}
      </h1>
      <p className="mt-3 max-w-2xl text-hubsom-ink/70">{meta.description}</p>
      <div className="mt-8">
        {products.length ? (
          <ProductGrid
            products={products}
            savedProductIds={user?.savedProductIds}
          />
        ) : (
          <EmptyState
            title={`No ${meta.name.toLowerCase()} yet`}
            body="List a product in this category to appear here."
            actionHref="/seller/products/new"
            actionLabel="Add product"
          />
        )}
      </div>
    </div>
  );
}

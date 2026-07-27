import type { Metadata } from "next";
import { ProductGrid } from "@/components/marketplace/ProductGrid";
import { EmptyState } from "@/components/ui/EmptyState";
import { getFlashSaleProducts } from "@/lib/data/products";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Flash sales",
};

export default async function FlashSalesPage() {
  const products = await getFlashSaleProducts();

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
        Flash sales
      </h1>
      <p className="mt-2 text-sm text-hubsom-ink/65">
        Timed discounts across categories.
      </p>
      <div className="mt-5">
        {products.length ? (
          <ProductGrid products={products} />
        ) : (
          <EmptyState
            title="No flash sales active"
            body="Add a flash sale when creating a product listing."
            actionHref="/seller/products/new"
            actionLabel="Create listing"
          />
        )}
      </div>
    </div>
  );
}

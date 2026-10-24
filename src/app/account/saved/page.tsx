import type { Metadata } from "next";
import { ProductGrid } from "@/components/marketplace/ProductGrid";
import { EmptyState } from "@/components/ui/EmptyState";
import { requireUser } from "@/lib/auth/session";
import { listSavedProducts } from "@/lib/data/saves";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Saved products",
};

export default async function SavedProductsPage() {
  const session = await requireUser("/account/saved");
  const products = await listSavedProducts(session.user.id);

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
        Saved
      </h1>
      <p className="mt-2 text-sm text-hubsom-ink/65">
        Favourites from live shows, auctions, and Buy Now.
      </p>

      <div className="mt-5">
        {!products.length ? (
          <EmptyState
            title="Nothing saved yet"
            body="Tap the heart on any product in marketplace, live, or auctions."
            actionHref="/marketplace"
            actionLabel="Browse marketplace"
          />
        ) : (
          <ProductGrid
            products={products}
            savedProductIds={products.map((p) => p.id)}
          />
        )}
      </div>
    </div>
  );
}

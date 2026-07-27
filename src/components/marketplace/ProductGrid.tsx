import { ProductCard } from "@/components/marketplace/ProductCard";
import type { Product } from "@/types";

export function ProductGrid({ products }: { products: Product[] }) {
  if (!products.length) {
    return (
      <p className="rounded-2xl border border-dashed border-hubsom-forest/20 bg-white/50 px-6 py-12 text-center text-hubsom-ink/60">
        No products in this view yet.
      </p>
    );
  }

  return (
    <div className="grid grid-cols-2 gap-3">
      {products.map((product) => (
        <ProductCard key={product.id} product={product} />
      ))}
    </div>
  );
}

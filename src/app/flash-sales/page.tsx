import type { Metadata } from "next";
import { ProductGrid } from "@/components/marketplace/ProductGrid";
import { Countdown } from "@/components/ui/Countdown";
import { getFlashSaleProducts } from "@/lib/data/products";

export const metadata: Metadata = {
  title: "Flash sales",
  description: "Timed Hubsom flash sales across all product categories.",
};

export default function FlashSalesPage() {
  const products = getFlashSaleProducts();
  const endsAt = products[0]?.flashSale?.endsAt;

  return (
    <div className="mx-auto max-w-7xl px-4 py-10 sm:px-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-display text-4xl font-extrabold text-hubsom-forest">
            Flash sales
          </h1>
          <p className="mt-3 max-w-2xl text-hubsom-ink/70">
            Limited-time pricing that works for produce, pantry, fashion, and tech
            alike.
          </p>
        </div>
        {endsAt && (
          <div className="rounded-xl bg-hubsom-live px-4 py-3 text-white">
            <p className="text-[11px] font-bold uppercase tracking-[0.16em]">
              Ends in
            </p>
            <p className="font-display text-2xl font-bold tabular-nums">
              <Countdown endsAt={endsAt} />
            </p>
          </div>
        )}
      </div>
      <div className="mt-8">
        <ProductGrid products={products} />
      </div>
    </div>
  );
}

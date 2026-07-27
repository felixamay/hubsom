import Link from "next/link";
import { CategoryRail } from "@/components/home/CategoryRail";
import { Hero } from "@/components/home/Hero";
import { LiveStrip } from "@/components/home/LiveStrip";
import { ProductGrid } from "@/components/marketplace/ProductGrid";
import { getFlashSaleProducts, PRODUCTS } from "@/lib/data/products";
import { listAllStreams } from "@/lib/data/stream-registry";
import { SELLERS } from "@/lib/data/sellers";

export default function HomePage() {
  const streams = listAllStreams();
  const live = streams.filter((s) => s.status === "live");
  const featured = PRODUCTS.slice(0, 6);
  const flash = getFlashSaleProducts();

  return (
    <>
      <Hero />
      <CategoryRail />
      <LiveStrip
        streams={[...live, ...streams.filter((s) => s.status !== "live")].slice(0, 2)}
      />

      <section className="px-4 py-6">
        <div className="mb-3 flex items-end justify-between">
          <div>
            <h2 className="font-display text-xl font-bold text-hubsom-forest">
              Buy Now
            </h2>
            <p className="mt-1 text-xs text-hubsom-ink/60">Shop anytime in GHS.</p>
          </div>
          <Link href="/marketplace" className="text-xs font-bold text-hubsom-cyan">
            Marketplace
          </Link>
        </div>
        <ProductGrid products={featured} />
      </section>

      <section className="px-4 py-6">
        <div className="mb-3 flex items-end justify-between">
          <div>
            <h2 className="font-display text-xl font-bold text-hubsom-forest">
              Flash sales
            </h2>
            <p className="mt-1 text-xs text-hubsom-ink/60">Timed drops, all categories.</p>
          </div>
          <Link href="/flash-sales" className="text-xs font-bold text-hubsom-cyan">
            All
          </Link>
        </div>
        <ProductGrid products={flash} />
      </section>

      <section className="px-4 py-6">
        <h2 className="font-display text-xl font-bold text-hubsom-forest">Stores</h2>
        <div className="mt-3 space-y-3">
          {SELLERS.map((seller) => (
            <Link
              key={seller.id}
              href={`/stores/${seller.slug}`}
              className="block rounded-2xl border border-hubsom-forest/10 bg-white/80 p-4"
            >
              <p className="font-display text-lg font-bold text-hubsom-forest">
                {seller.name}
              </p>
              <p className="mt-0.5 text-xs text-hubsom-ink/55">
                {seller.city}, {seller.region}
              </p>
              <p className="mt-2 line-clamp-2 text-sm text-hubsom-ink/70">
                {seller.bio}
              </p>
            </Link>
          ))}
        </div>
      </section>
    </>
  );
}

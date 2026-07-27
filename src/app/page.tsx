import Link from "next/link";
import { CategoryRail } from "@/components/home/CategoryRail";
import { Hero } from "@/components/home/Hero";
import { LiveStrip } from "@/components/home/LiveStrip";
import { ProductGrid } from "@/components/marketplace/ProductGrid";
import { getFlashSaleProducts, PRODUCTS } from "@/lib/data/products";
import { getLiveStreams, STREAMS } from "@/lib/data/streams";
import { SELLERS } from "@/lib/data/sellers";

export default function HomePage() {
  const live = getLiveStreams();
  const featured = PRODUCTS.slice(0, 8);
  const flash = getFlashSaleProducts();

  return (
    <>
      <Hero />
      <CategoryRail />
      <LiveStrip streams={[...live, ...STREAMS.filter((s) => s.status !== "live")].slice(0, 3)} />

      <section className="mx-auto max-w-7xl px-4 py-10 sm:px-6">
        <div className="mb-6 flex items-end justify-between">
          <div>
            <h2 className="font-display text-3xl font-bold text-hubsom-forest">
              Buy Now marketplace
            </h2>
            <p className="mt-2 text-hubsom-ink/70">
              Same catalog sellers pin on live — shop anytime in GHS.
            </p>
          </div>
          <Link href="/marketplace" className="text-sm font-semibold text-hubsom-leaf">
            Open marketplace
          </Link>
        </div>
        <ProductGrid products={featured} />
      </section>

      <section className="mx-auto max-w-7xl px-4 py-10 sm:px-6">
        <div className="mb-6 flex items-end justify-between">
          <div>
            <h2 className="font-display text-3xl font-bold text-hubsom-forest">
              Flash sales
            </h2>
            <p className="mt-2 text-hubsom-ink/70">
              Timed drops across produce, electronics, and more — never a grocery-only lane.
            </p>
          </div>
          <Link href="/flash-sales" className="text-sm font-semibold text-hubsom-leaf">
            All flash sales
          </Link>
        </div>
        <ProductGrid products={flash} />
      </section>

      <section className="mx-auto max-w-7xl px-4 py-16 sm:px-6">
        <h2 className="font-display text-3xl font-bold text-hubsom-forest">Seller stores</h2>
        <p className="mt-2 max-w-2xl text-hubsom-ink/70">
          Independent storefronts with live shows, auctions, and Buy Now inventory.
        </p>
        <div className="mt-8 grid gap-4 md:grid-cols-2">
          {SELLERS.map((seller) => (
            <Link
              key={seller.id}
              href={`/stores/${seller.slug}`}
              className="rounded-3xl border border-hubsom-forest/10 bg-white/70 p-6 transition hover:border-hubsom-leaf/40"
            >
              <p className="font-display text-2xl font-bold text-hubsom-forest">
                {seller.name}
              </p>
              <p className="mt-1 text-sm text-hubsom-ink/60">
                {seller.city}, {seller.region}
              </p>
              <p className="mt-3 text-sm leading-relaxed text-hubsom-ink/75">
                {seller.bio}
              </p>
            </Link>
          ))}
        </div>
      </section>
    </>
  );
}

import Link from "next/link";
import { CategoryRail } from "@/components/home/CategoryRail";
import { HomeSearchHero } from "@/components/home/HomeSearchHero";
import { LiveStrip } from "@/components/home/LiveStrip";
import { ProductGrid } from "@/components/marketplace/ProductGrid";
import { PromoSpace } from "@/components/promotions/PromoSpace";
import { FollowButton } from "@/components/sellers/FollowButton";
import { EmptyState } from "@/components/ui/EmptyState";
import { auth } from "@/auth";
import { isFollowingSeller, isOwnSellerStore } from "@/lib/data/follows";
import { getFlashSaleProducts, listProducts } from "@/lib/data/products";
import { listPromotions } from "@/lib/data/promotions";
import { listSellers } from "@/lib/data/sellers";
import { listAllStreams } from "@/lib/data/stream-registry";
import { getUserById } from "@/lib/data/users";

export const dynamic = "force-dynamic";

export default async function HomePage() {
  const [streams, products, flash, sellers, session, promotions] =
    await Promise.all([
      listAllStreams(),
      listProducts(),
      getFlashSaleProducts(),
      listSellers(),
      auth(),
      listPromotions({ placement: "landing", limit: 4 }),
    ]);
  const live = streams.filter((s) => s.status === "live");
  const featured = products.slice(0, 6);
  const userId = session?.user?.id;
  const user = userId ? await getUserById(userId) : null;

  const followState = userId
    ? await Promise.all(
        sellers.map(async (seller) => ({
          id: seller.id,
          following: await isFollowingSeller(userId, seller.id),
          isOwnStore: isOwnSellerStore(user, seller),
        })),
      )
    : sellers.map((seller) => ({
        id: seller.id,
        following: false,
        isOwnStore: false,
      }));
  const followMap = Object.fromEntries(
    followState.map((f) => [f.id, f]),
  );

  return (
    <>
      <HomeSearchHero />
      <CategoryRail />
      <div className="px-4 pt-2">
        <PromoSpace
          promotions={promotions}
          title="Promotions"
          subtitle="Live drops, flash deals, and partner offers."
        />
      </div>
      <LiveStrip
        streams={[...live, ...streams.filter((s) => s.status !== "live")].slice(
          0,
          2,
        )}
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
        {featured.length ? (
          <ProductGrid
            products={featured}
            savedProductIds={user?.savedProductIds}
          />
        ) : (
          <EmptyState
            title="No listings yet"
            body="Add your first product to start selling on Hubsom."
            actionHref="/seller/products/new"
            actionLabel="Add product"
          />
        )}
      </section>

      <section className="px-4 py-6">
        <div className="mb-3 flex items-end justify-between">
          <div>
            <h2 className="font-display text-xl font-bold text-hubsom-forest">
              Flash sales
            </h2>
            <p className="mt-1 text-xs text-hubsom-ink/60">
              Timed drops, all categories.
            </p>
          </div>
          <Link href="/flash-sales" className="text-xs font-bold text-hubsom-cyan">
            All
          </Link>
        </div>
        {flash.length ? (
          <ProductGrid
            products={flash}
            savedProductIds={user?.savedProductIds}
          />
        ) : (
          <EmptyState
            title="No flash sales live"
            body="Create a product with a flash sale window from the seller tools."
            actionHref="/seller/products/new"
            actionLabel="Create listing"
          />
        )}
      </section>

      <section className="px-4 py-6">
        <h2 className="font-display text-xl font-bold text-hubsom-forest">Stores</h2>
        <div className="mt-3 space-y-3">
          {!sellers.length && (
            <EmptyState
              title="No stores yet"
              body="Set up your seller storefront and go live."
              actionHref="/seller"
              actionLabel="Open seller hub"
            />
          )}
          {sellers.map((seller) => {
            const state = followMap[seller.id];
            return (
              <div
                key={seller.id}
                className="rounded-2xl border border-hubsom-forest/10 bg-white/80 p-4"
              >
                <div className="flex items-start justify-between gap-3">
                  <Link href={`/stores/${seller.slug}`} className="min-w-0 flex-1">
                    <p className="font-display text-lg font-bold text-hubsom-forest">
                      {seller.name}
                    </p>
                    <p className="mt-0.5 text-xs text-hubsom-ink/55">
                      {seller.city}, {seller.region} ·{" "}
                      {seller.followers.toLocaleString()} followers
                    </p>
                    <p className="mt-2 line-clamp-2 text-sm text-hubsom-ink/70">
                      {seller.bio}
                    </p>
                  </Link>
                  <FollowButton
                    sellerId={seller.id}
                    initialFollowing={state?.following}
                    initialFollowers={seller.followers}
                    isOwnStore={state?.isOwnStore}
                    size="sm"
                    className="shrink-0"
                  />
                </div>
              </div>
            );
          })}
        </div>
      </section>
    </>
  );
}

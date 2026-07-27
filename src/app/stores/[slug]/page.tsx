import Image from "next/image";
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { FollowButton } from "@/components/sellers/FollowButton";
import { ProductGrid } from "@/components/marketplace/ProductGrid";
import { EmptyState } from "@/components/ui/EmptyState";
import { auth } from "@/auth";
import { isFollowingSeller } from "@/lib/data/follows";
import { getProductsBySeller } from "@/lib/data/products";
import { getSellerBySlug } from "@/lib/data/sellers";
import { getStreamsBySeller } from "@/lib/data/streams";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const seller = await getSellerBySlug(slug);
  return { title: seller?.name ?? "Store" };
}

export default async function StorePage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const seller = await getSellerBySlug(slug);
  if (!seller) notFound();

  const session = await auth();
  const userId = session?.user?.id;
  const isOwnStore = Boolean(
    userId &&
      (seller.ownerUserId === userId || session?.user?.sellerId === seller.id),
  );
  const following = userId
    ? await isFollowingSeller(userId, seller.id)
    : false;

  const products = await getProductsBySeller(seller.id);
  const streams = await getStreamsBySeller(seller.id);

  return (
    <div>
      <section className="relative h-64 overflow-hidden bg-hubsom-night sm:h-80">
        <Image
          src={seller.cover}
          alt=""
          fill
          className="object-cover"
          sizes="100vw"
          priority
        />
        <div className="absolute inset-0 bg-gradient-to-t from-hubsom-night via-hubsom-night/50 to-transparent" />
        <div className="absolute bottom-0 left-0 right-0 mx-auto flex max-w-7xl items-end gap-4 px-4 pb-6 sm:px-6">
          <Image
            src={seller.avatar}
            alt={seller.name}
            width={72}
            height={72}
            className="rounded-2xl border-2 border-white bg-white object-cover"
          />
          <div className="min-w-0 flex-1 text-white">
            <h1 className="font-display text-3xl font-extrabold sm:text-4xl">
              {seller.name}
            </h1>
            <p className="text-sm text-white/75">
              {seller.city}, {seller.region} · {seller.followers.toLocaleString()}{" "}
              followers
            </p>
          </div>
          {isOwnStore ? (
            <Link
              href="/seller/store"
              className="mb-1 shrink-0 rounded-xl bg-hubsom-gold px-3 py-2 text-xs font-bold text-hubsom-ink"
            >
              Edit store
            </Link>
          ) : (
            <FollowButton
              sellerId={seller.id}
              initialFollowing={following}
              initialFollowers={seller.followers}
              isOwnStore={isOwnStore}
              className="mb-1 shrink-0"
            />
          )}
        </div>
      </section>

      <div className="mx-auto max-w-7xl px-4 py-10 sm:px-6">
        <p className="max-w-2xl text-hubsom-ink/75">{seller.bio}</p>

        {!!streams.length && (
          <div className="mt-10">
            <h2 className="font-display text-2xl font-bold text-hubsom-forest">
              Shows
            </h2>
            <div className="mt-4 flex flex-wrap gap-3">
              {streams.map((s) => (
                <Link
                  key={s.id}
                  href={`/live/${s.id}`}
                  className="rounded-xl border border-hubsom-forest/10 bg-white/70 px-4 py-3 text-sm font-semibold text-hubsom-forest"
                >
                  {s.title} · {s.status}
                </Link>
              ))}
            </div>
          </div>
        )}

        <div className="mt-10">
          <h2 className="mb-5 font-display text-2xl font-bold text-hubsom-forest">
            Store listings
          </h2>
          {products.length ? (
            <ProductGrid products={products} />
          ) : (
            <EmptyState
              title="No listings yet"
              body="Add products to this store to sell Buy Now and live."
              actionHref="/seller/products/new"
              actionLabel="Add product"
            />
          )}
        </div>
      </div>
    </div>
  );
}

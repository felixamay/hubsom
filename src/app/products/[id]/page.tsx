import Image from "next/image";
import Link from "next/link";
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Star } from "lucide-react";
import { AddToCartButton } from "@/components/cart/AddToCartButton";
import { ProductReviewsSection } from "@/components/product/ProductReviewsSection";
import { SaveProductButton } from "@/components/product/SaveProductButton";
import { FollowButton } from "@/components/sellers/FollowButton";
import { auth } from "@/auth";
import { categoryName } from "@/lib/categories";
import { formatGhs } from "@/lib/currency";
import { isFollowingSeller } from "@/lib/data/follows";
import { userHasPurchasedProduct } from "@/lib/data/orders";
import {
  getUserProductReview,
  listReviewsForProduct,
} from "@/lib/data/product-reviews";
import { getProduct, getProductBySlug } from "@/lib/data/products";
import { isProductSaved } from "@/lib/data/saves";
import { getSeller } from "@/lib/data/sellers";
import { getEffectivePrice } from "@/lib/pricing";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const product = (await getProductBySlug(id)) ?? (await getProduct(id));
  return { title: product?.name ?? "Product" };
}

export default async function ProductPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const product = (await getProductBySlug(id)) ?? (await getProduct(id));
  if (!product) notFound();
  const seller = await getSeller(product.sellerId);
  const price = getEffectivePrice(product);

  const session = await auth();
  const userId = session?.user?.id;
  const isOwnStore = Boolean(
    userId &&
      seller &&
      (seller.ownerUserId === userId || session?.user?.sellerId === seller.id),
  );
  const following =
    userId && seller ? await isFollowingSeller(userId, seller.id) : false;
  const saved = userId ? await isProductSaved(userId, product.id) : false;
  const canReview = userId
    ? await userHasPurchasedProduct(userId, product.id)
    : false;
  const reviews = await listReviewsForProduct(product.id);
  const myReview = userId
    ? await getUserProductReview(product.id, userId)
    : null;

  return (
    <div className="mx-auto max-w-7xl px-4 py-10 sm:px-6">
      <div className="grid gap-10 lg:grid-cols-2">
        <div className="relative aspect-square overflow-hidden rounded-3xl bg-hubsom-mint">
          <Image
            src={product.images[0]}
            alt={product.name}
            fill
            className="object-cover"
            sizes="(max-width:1024px) 100vw, 50vw"
            priority
          />
          <div className="absolute right-3 top-3 z-10">
            <SaveProductButton
              productId={product.id}
              initialSaved={saved}
              size="icon"
              variant="overlay"
            />
          </div>
        </div>
        <div>
          <Link
            href={`/categories/${product.category}`}
            className="text-xs font-bold uppercase tracking-[0.18em] text-hubsom-leaf"
          >
            {categoryName(product.category)}
          </Link>
          <h1 className="mt-3 font-display text-4xl font-extrabold text-hubsom-forest">
            {product.name}
          </h1>
          {product.reviewCount > 0 ? (
            <p className="mt-2 inline-flex items-center gap-1.5 text-sm text-hubsom-ink/65">
              <Star className="h-4 w-4 fill-hubsom-gold text-hubsom-gold" />
              {product.rating.toFixed(1)} · {product.reviewCount} review
              {product.reviewCount === 1 ? "" : "s"}
            </p>
          ) : null}
          <p className="mt-4 text-hubsom-ink/75">{product.description}</p>
          <div className="mt-6 flex items-baseline gap-3">
            <span className="text-3xl font-bold text-hubsom-forest">
              {formatGhs(price)}
            </span>
            {product.compareAtGhs && (
              <span className="text-lg text-hubsom-ink/40 line-through">
                {formatGhs(product.compareAtGhs)}
              </span>
            )}
          </div>
          <p className="mt-2 text-sm text-hubsom-ink/60">
            {product.stock} in stock · synced with live shows
          </p>
          <div className="mt-6 flex flex-wrap items-center gap-3">
            <AddToCartButton product={product} />
            <SaveProductButton
              productId={product.id}
              initialSaved={saved}
              size="md"
              variant="default"
              label
            />
          </div>
          <div className="mt-8 rounded-2xl border border-hubsom-forest/10 bg-white/70 p-5">
            <p className="text-xs font-bold uppercase tracking-[0.16em] text-hubsom-leaf">
              Sold by
            </p>
            {seller && (
              <div className="mt-2 flex items-center justify-between gap-3">
                <Link
                  href={`/stores/${seller.slug}`}
                  className="min-w-0 font-display text-2xl font-semibold text-hubsom-forest hover:underline"
                >
                  {seller.name}
                </Link>
                <FollowButton
                  sellerId={seller.id}
                  initialFollowing={following}
                  initialFollowers={seller.followers}
                  isOwnStore={isOwnStore}
                  size="sm"
                  className="shrink-0"
                />
              </div>
            )}
          </div>
        </div>
      </div>

      <ProductReviewsSection
        productId={product.id}
        initialReviews={reviews}
        initialRating={product.rating}
        initialReviewCount={product.reviewCount}
        canReview={canReview}
        myReview={myReview}
      />
    </div>
  );
}

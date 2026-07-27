import Image from "next/image";
import Link from "next/link";
import { categoryName } from "@/lib/categories";
import { formatGhs } from "@/lib/currency";
import { getEffectivePrice } from "@/lib/pricing";
import type { Product } from "@/types";

export function ProductCard({ product }: { product: Product }) {
  const price = getEffectivePrice(product);

  return (
    <Link
      href={`/products/${product.slug}`}
      className="group block overflow-hidden rounded-2xl border border-hubsom-forest/10 bg-white/80 transition active:scale-[0.99]"
    >
      <div className="relative aspect-square overflow-hidden bg-hubsom-mint">
        <Image
          src={product.images[0]}
          alt={product.name}
          fill
          className="object-cover transition duration-500 group-hover:scale-105"
          sizes="50vw"
        />
        {product.flashSale && (
          <span className="absolute left-2 top-2 rounded-md bg-hubsom-live px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide text-white">
            −{product.flashSale.discountPct}%
          </span>
        )}
      </div>
      <div className="space-y-1 p-3">
        <p className="text-[10px] font-semibold uppercase tracking-[0.12em] text-hubsom-leaf">
          {categoryName(product.category)}
        </p>
        <h3 className="line-clamp-2 font-display text-sm font-semibold leading-snug text-hubsom-ink">
          {product.name}
        </h3>
        <div className="flex flex-wrap items-baseline gap-1.5">
          <span className="text-sm font-bold text-hubsom-forest">
            {formatGhs(price)}
          </span>
          {product.compareAtGhs && (
            <span className="text-xs text-hubsom-ink/45 line-through">
              {formatGhs(product.compareAtGhs)}
            </span>
          )}
        </div>
      </div>
    </Link>
  );
}

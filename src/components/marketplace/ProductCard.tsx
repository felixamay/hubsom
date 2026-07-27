import Image from "next/image";
import Link from "next/link";
import { categoryName } from "@/lib/categories";
import { formatGhs } from "@/lib/currency";
import { getEffectivePrice } from "@/lib/data/products";
import type { Product } from "@/types";

export function ProductCard({ product }: { product: Product }) {
  const price = getEffectivePrice(product);

  return (
    <Link
      href={`/products/${product.slug}`}
      className="group block overflow-hidden rounded-2xl border border-hubsom-forest/10 bg-white/70 transition hover:-translate-y-0.5 hover:border-hubsom-leaf/40 hover:shadow-[0_18px_40px_-28px_rgba(11,61,46,0.55)]"
    >
      <div className="relative aspect-[4/3] overflow-hidden bg-hubsom-mint">
        <Image
          src={product.images[0]}
          alt={product.name}
          fill
          className="object-cover transition duration-500 group-hover:scale-105"
          sizes="(max-width:768px) 50vw, 25vw"
        />
        {product.flashSale && (
          <span className="absolute left-3 top-3 rounded-md bg-hubsom-live px-2 py-1 text-[11px] font-bold uppercase tracking-wide text-white">
            Flash −{product.flashSale.discountPct}%
          </span>
        )}
      </div>
      <div className="space-y-2 p-4">
        <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-hubsom-leaf">
          {categoryName(product.category)}
        </p>
        <h3 className="font-display text-lg font-semibold leading-snug text-hubsom-ink">
          {product.name}
        </h3>
        <div className="flex items-baseline gap-2">
          <span className="text-base font-bold text-hubsom-forest">
            {formatGhs(price)}
          </span>
          {product.compareAtGhs && (
            <span className="text-sm text-hubsom-ink/45 line-through">
              {formatGhs(product.compareAtGhs)}
            </span>
          )}
        </div>
      </div>
    </Link>
  );
}

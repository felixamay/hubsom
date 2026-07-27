import Image from "next/image";
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ProductGrid } from "@/components/marketplace/ProductGrid";
import { getProductsBySeller } from "@/lib/data/products";
import { getSellerBySlug } from "@/lib/data/sellers";
import { getStreamsBySeller } from "@/lib/data/streams";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const seller = getSellerBySlug(slug);
  return { title: seller?.name ?? "Store" };
}

export default async function StorePage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const seller = getSellerBySlug(slug);
  if (!seller) notFound();

  const products = getProductsBySeller(seller.id);
  const streams = getStreamsBySeller(seller.id);

  return (
    <div>
      <section className="relative h-64 overflow-hidden sm:h-80">
        <Image
          src={seller.cover}
          alt=""
          fill
          className="object-cover"
          sizes="100vw"
          priority
        />
        <div className="absolute inset-0 bg-gradient-to-t from-hubsom-night via-hubsom-night/40 to-transparent" />
        <div className="absolute bottom-0 left-0 right-0 mx-auto flex max-w-7xl items-end gap-4 px-4 pb-6 sm:px-6">
          <Image
            src={seller.avatar}
            alt={seller.name}
            width={72}
            height={72}
            className="rounded-2xl border-2 border-white object-cover"
          />
          <div className="text-white">
            <h1 className="font-display text-3xl font-extrabold sm:text-4xl">
              {seller.name}
            </h1>
            <p className="text-sm text-white/75">
              {seller.city}, {seller.region} · {seller.followers.toLocaleString()}{" "}
              followers · {seller.rating}★
            </p>
          </div>
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
          <ProductGrid products={products} />
        </div>
      </div>
    </div>
  );
}

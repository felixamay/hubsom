import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { EmptyState } from "@/components/ui/EmptyState";
import { CATEGORIES } from "@/lib/categories";
import { categoryImage } from "@/lib/category-images";
import { getSeller } from "@/lib/data/sellers";
import { listAllStreams } from "@/lib/data/stream-registry";
import type { LiveStream, ProductCategory } from "@/types";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Live by category",
};

export default async function LiveIndexPage() {
  const streams = await listAllStreams();
  const liveFirst = [...streams].sort((a, b) => {
    const rank = (s: LiveStream) =>
      s.status === "live" ? 0 : s.status === "scheduled" ? 1 : 2;
    return rank(a) - rank(b);
  });

  const withSellers = await Promise.all(
    liveFirst.map(async (stream) => ({
      stream,
      seller: await getSeller(stream.sellerId),
    })),
  );

  const byCategory = new Map<
    ProductCategory,
    { stream: LiveStream; sellerName: string }[]
  >();

  for (const row of withSellers) {
    const cats =
      row.stream.categories.length > 0
        ? row.stream.categories
        : (["miscellaneous"] as ProductCategory[]);
    for (const cat of cats) {
      const list = byCategory.get(cat) ?? [];
      if (!list.some((s) => s.stream.id === row.stream.id)) {
        list.push({
          stream: row.stream,
          sellerName: row.seller?.name ?? "Seller",
        });
      }
      byCategory.set(cat, list);
    }
  }

  const sections = CATEGORIES.filter((c) => byCategory.has(c.slug)).map(
    (c) => ({
      meta: c,
      streams: byCategory.get(c.slug)!,
    }),
  );

  const uncategorized = withSellers.filter((r) => !r.stream.categories.length);

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
            Live
          </h1>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            All live shows grouped by category.
          </p>
        </div>
        <Link
          href="/seller/go-live"
          className="rounded-xl bg-hubsom-live px-3 py-2 text-xs font-bold text-white"
        >
          Go live
        </Link>
      </div>

      {!liveFirst.length ? (
        <div className="mt-5">
          <EmptyState
            title="No shows yet"
            body="Start the first Hubsom live commerce show."
            actionHref="/seller/go-live"
            actionLabel="Start a show"
          />
        </div>
      ) : null}

      <div className="mt-6 space-y-8">
        {sections.map(({ meta, streams: catStreams }) => (
          <section key={meta.slug} id={`live-${meta.slug}`}>
            <div className="mb-3 flex items-center justify-between gap-3">
              <div className="flex items-center gap-2.5">
                <div className="relative h-9 w-9 overflow-hidden rounded-xl bg-hubsom-mist ring-1 ring-hubsom-forest/10">
                  <Image
                    src={categoryImage(meta.slug)}
                    alt=""
                    fill
                    sizes="36px"
                    className="object-contain p-1.5"
                  />
                </div>
                <div>
                  <h2 className="font-display text-lg font-bold text-hubsom-forest">
                    {meta.name}
                  </h2>
                  <p className="text-[11px] text-hubsom-ink/55">
                    {
                      catStreams.filter((s) => s.stream.status === "live")
                        .length
                    }{" "}
                    live · {catStreams.length} total
                  </p>
                </div>
              </div>
              <Link
                href={`/categories/${meta.slug}`}
                className="text-xs font-bold text-hubsom-cyan"
              >
                Shop
              </Link>
            </div>

            <div className="scrollbar-thin -mx-1 flex gap-2.5 overflow-x-auto px-1 pb-1">
              {catStreams.map(({ stream, sellerName }) => {
                const cover =
                  stream.cover?.startsWith("http") ||
                  stream.cover?.startsWith("/")
                    ? stream.cover
                    : categoryImage(meta.slug);

                return (
                  <Link
                    key={`${meta.slug}-${stream.id}`}
                    href={`/live/${stream.id}`}
                    className="w-[7.25rem] shrink-0"
                  >
                    <div className="relative aspect-[3/4] overflow-hidden rounded-[1.1rem] bg-hubsom-night ring-1 ring-black/10">
                      <Image
                        src={cover}
                        alt=""
                        fill
                        sizes="116px"
                        className="object-cover"
                      />
                      <div className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/15 to-transparent" />
                      <span
                        className={`absolute left-2 top-2 rounded-md px-1.5 py-0.5 text-[9px] font-bold uppercase text-white ${
                          stream.status === "live"
                            ? "bg-hubsom-live"
                            : "bg-black/55"
                        }`}
                      >
                        {stream.status}
                      </span>
                      <div className="absolute inset-x-0 bottom-0 p-2.5 text-white">
                        <p className="line-clamp-2 font-display text-[12px] font-bold leading-snug">
                          {stream.title}
                        </p>
                        <p className="mt-0.5 truncate text-[10px] text-white/75">
                          {sellerName} · {stream.viewerCount.toLocaleString()}
                        </p>
                      </div>
                    </div>
                  </Link>
                );
              })}
            </div>
          </section>
        ))}

        {uncategorized.length ? (
          <section>
            <h2 className="mb-3 font-display text-lg font-bold text-hubsom-forest">
              Other shows
            </h2>
            <div className="space-y-2">
              {uncategorized.map(({ stream, seller }) => (
                <Link
                  key={stream.id}
                  href={`/live/${stream.id}`}
                  className="block rounded-2xl border border-hubsom-forest/10 bg-white/80 p-4"
                >
                  <div className="flex items-center justify-between gap-2">
                    <p className="font-display text-base font-bold text-hubsom-ink">
                      {stream.title}
                    </p>
                    <span className="rounded-md bg-hubsom-live px-2 py-1 text-[10px] font-bold uppercase text-white">
                      {stream.status}
                    </span>
                  </div>
                  <p className="mt-1 text-xs text-hubsom-ink/55">
                    {seller?.name ?? "Seller"} ·{" "}
                    {stream.viewerCount.toLocaleString()} viewers
                  </p>
                </Link>
              ))}
            </div>
          </section>
        ) : null}
      </div>
    </div>
  );
}

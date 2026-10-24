import Image from "next/image";
import Link from "next/link";
import { EmptyState } from "@/components/ui/EmptyState";
import { getSeller } from "@/lib/data/sellers";
import type { LiveStream } from "@/types";

export async function LiveStrip({ streams }: { streams: LiveStream[] }) {
  if (!streams.length) {
    return (
      <section className="px-4 py-4">
        <div className="mb-3 flex items-end justify-between gap-3">
          <div>
            <h2 className="font-display text-xl font-bold text-hubsom-forest">
              Happening live
            </h2>
            <p className="mt-1 text-xs text-hubsom-ink/60">
              Mixed-category shows — one cart.
            </p>
          </div>
          <Link href="/live" className="text-xs font-bold text-hubsom-cyan">
            See all
          </Link>
        </div>
        <EmptyState
          title="No live shows right now"
          body="Go live from the seller hub to start selling on camera."
          actionHref="/seller/go-live"
          actionLabel="Go live"
        />
      </section>
    );
  }

  const withSellers = await Promise.all(
    streams.map(async (stream) => ({
      stream,
      seller: await getSeller(stream.sellerId),
    })),
  );

  return (
    <section className="px-4 py-4">
      <div className="mb-3 flex items-end justify-between gap-3">
        <div>
          <h2 className="font-display text-xl font-bold text-hubsom-forest">
            Happening live
          </h2>
          <p className="mt-1 text-xs text-hubsom-ink/60">
            Mixed-category shows — one cart.
          </p>
        </div>
        <Link href="/live" className="text-xs font-bold text-hubsom-cyan">
          See all
        </Link>
      </div>
      <div className="flex flex-col gap-3">
        {withSellers.map(({ stream, seller }) => (
          <Link
            key={stream.id}
            href={`/live/${stream.id}`}
            className="group relative overflow-hidden rounded-2xl border border-hubsom-forest/10 bg-hubsom-night"
          >
            <div className="relative aspect-[16/9]">
              <Image
                src={stream.cover}
                alt={stream.title}
                fill
                className="object-cover transition duration-500 group-hover:scale-105"
                sizes="(max-width:512px) 100vw, 512px"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/20 to-transparent" />
              <span className="absolute left-3 top-3 rounded-md bg-hubsom-live px-2 py-1 text-[10px] font-bold uppercase text-white">
                {stream.status}
              </span>
            </div>
            <div className="absolute inset-x-0 bottom-0 p-3 text-white">
              <p className="font-display text-base font-semibold leading-snug">
                {stream.title}
              </p>
              <p className="mt-0.5 text-xs text-white/75">
                {seller?.name ?? "Hubsom seller"} ·{" "}
                {stream.viewerCount.toLocaleString()} viewers
              </p>
            </div>
          </Link>
        ))}
      </div>
    </section>
  );
}

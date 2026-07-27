import Image from "next/image";
import Link from "next/link";
import { getSeller } from "@/lib/data/sellers";
import type { LiveStream } from "@/types";

export function LiveStrip({ streams }: { streams: LiveStream[] }) {
  return (
    <section className="mx-auto max-w-7xl px-4 py-16 sm:px-6">
      <div className="mb-8 flex items-end justify-between gap-4">
        <div>
          <h2 className="font-display text-3xl font-bold text-hubsom-forest sm:text-4xl">
            Happening live
          </h2>
          <p className="mt-2 max-w-xl text-hubsom-ink/70">
            Mixed-category shows — groceries next to gadgets, same cart, same checkout.
          </p>
        </div>
        <Link href="/live" className="text-sm font-semibold text-hubsom-leaf hover:underline">
          See all
        </Link>
      </div>
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {streams.map((stream) => {
          const seller = getSeller(stream.sellerId);
          return (
            <Link
              key={stream.id}
              href={`/live/${stream.id}`}
              className="group relative overflow-hidden rounded-3xl border border-hubsom-forest/10 bg-hubsom-night"
            >
              <div className="relative aspect-[16/10]">
                <Image
                  src={stream.cover}
                  alt={stream.title}
                  fill
                  className="object-cover transition duration-500 group-hover:scale-105"
                  sizes="(max-width:768px) 100vw, 33vw"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent" />
                <span className="absolute left-3 top-3 rounded-md bg-hubsom-live px-2 py-1 text-[11px] font-bold uppercase text-white">
                  {stream.status}
                </span>
              </div>
              <div className="absolute inset-x-0 bottom-0 p-4 text-white">
                <p className="font-display text-xl font-semibold leading-snug">
                  {stream.title}
                </p>
                <p className="mt-1 text-sm text-white/75">
                  {seller?.name} · {stream.viewerCount.toLocaleString()} viewers
                </p>
              </div>
            </Link>
          );
        })}
      </div>
    </section>
  );
}

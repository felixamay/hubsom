import Image from "next/image";
import Link from "next/link";
import type { Metadata } from "next";
import { getSeller } from "@/lib/data/sellers";
import { STREAMS } from "@/lib/data/streams";

export const metadata: Metadata = {
  title: "Live shopping",
  description: "Watch Hubsom live commerce shows with mixed product categories.",
};

export default function LiveIndexPage() {
  return (
    <div className="mx-auto max-w-7xl px-4 py-10 sm:px-6">
      <h1 className="font-display text-4xl font-extrabold text-hubsom-forest sm:text-5xl">
        Live on Hubsom
      </h1>
      <p className="mt-3 max-w-2xl text-hubsom-ink/70">
        Ultra-low latency shopping streams with chat, reactions, pinning, auctions,
        and one-tap checkout — produce beside phones in the same show.
      </p>

      <div className="mt-10 grid gap-5 md:grid-cols-2">
        {STREAMS.map((stream) => {
          const seller = getSeller(stream.sellerId);
          return (
            <Link
              key={stream.id}
              href={`/live/${stream.id}`}
              className="overflow-hidden rounded-3xl border border-hubsom-forest/10 bg-white/70"
            >
              <div className="relative aspect-[16/9]">
                <Image
                  src={stream.cover}
                  alt={stream.title}
                  fill
                  className="object-cover"
                  sizes="(max-width:768px) 100vw, 50vw"
                />
                <span className="absolute left-3 top-3 rounded-md bg-hubsom-live px-2 py-1 text-[11px] font-bold uppercase text-white">
                  {stream.status}
                </span>
              </div>
              <div className="space-y-2 p-5">
                <h2 className="font-display text-2xl font-semibold text-hubsom-ink">
                  {stream.title}
                </h2>
                <p className="text-sm text-hubsom-ink/65">
                  {seller?.name} · {stream.viewerCount.toLocaleString()} viewers ·{" "}
                  {stream.categories.length} categories
                </p>
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}

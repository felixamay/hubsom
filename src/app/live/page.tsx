import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { getSeller } from "@/lib/data/sellers";
import { listAllStreams } from "@/lib/data/stream-registry";

export const metadata: Metadata = {
  title: "Live shopping",
  description: "Watch Hubsom live commerce shows with mixed product categories.",
};

export default async function LiveIndexPage() {
  const streams = await listAllStreams();

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
            Live
          </h1>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Ultra-low latency shopping with chat, pins, auctions, and checkout.
          </p>
        </div>
        <Link
          href="/seller/go-live"
          className="rounded-xl bg-hubsom-live px-3 py-2 text-xs font-bold text-white"
        >
          Go live
        </Link>
      </div>

      <div className="mt-5 space-y-4">
        {streams.map((stream) => {
          const seller = getSeller(stream.sellerId);
          return (
            <Link
              key={stream.id}
              href={`/live/${stream.id}`}
              className="block overflow-hidden rounded-2xl border border-hubsom-forest/10 bg-white/80"
            >
              <div className="relative aspect-[16/9]">
                <Image
                  src={stream.cover}
                  alt={stream.title}
                  fill
                  className="object-cover"
                  sizes="100vw"
                />
                <span className="absolute left-3 top-3 rounded-md bg-hubsom-live px-2 py-1 text-[10px] font-bold uppercase text-white">
                  {stream.status}
                </span>
              </div>
              <div className="space-y-1 p-4">
                <h2 className="font-display text-lg font-semibold text-hubsom-ink">
                  {stream.title}
                </h2>
                <p className="text-xs text-hubsom-ink/60">
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

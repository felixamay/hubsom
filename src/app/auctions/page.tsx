import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { Countdown } from "@/components/ui/Countdown";
import { formatGhs } from "@/lib/currency";
import { getProduct } from "@/lib/data/products";
import { getSeller } from "@/lib/data/sellers";
import { STREAMS } from "@/lib/data/streams";

export const metadata: Metadata = {
  title: "Live auctions",
  description: "Bid live on Hubsom across every product category.",
};

export default function AuctionsPage() {
  const auctions = STREAMS.filter((s) => s.auction);

  return (
    <div className="mx-auto max-w-7xl px-4 py-10 sm:px-6">
      <h1 className="font-display text-4xl font-extrabold text-hubsom-forest">
        Live auctions
      </h1>
      <p className="mt-3 max-w-2xl text-hubsom-ink/70">
        Countdown timers, realtime bids, and checkout into the same cart — phones,
        kente, seafood, sneakers.
      </p>

      <div className="mt-10 grid gap-5 md:grid-cols-2">
        {auctions.map((stream) => {
          const auction = stream.auction!;
          const product = getProduct(auction.productId);
          const seller = getSeller(stream.sellerId);
          return (
            <Link
              key={auction.id}
              href={`/live/${stream.id}`}
              className="overflow-hidden rounded-3xl border border-hubsom-forest/10 bg-white/70"
            >
              <div className="relative aspect-[16/9]">
                <Image
                  src={product?.images[0] ?? stream.cover}
                  alt={product?.name ?? stream.title}
                  fill
                  className="object-cover"
                  sizes="(max-width:768px) 100vw, 50vw"
                />
              </div>
              <div className="space-y-2 p-5">
                <div className="flex items-center justify-between gap-3">
                  <h2 className="font-display text-2xl font-semibold text-hubsom-ink">
                    {product?.name}
                  </h2>
                  <span className="rounded-md bg-hubsom-live px-2 py-1 text-xs font-bold text-white tabular-nums">
                    <Countdown endsAt={auction.endsAt} />
                  </span>
                </div>
                <p className="text-sm text-hubsom-ink/65">
                  {seller?.name} · {auction.bidderCount} bidders
                </p>
                <p className="text-lg font-bold text-hubsom-forest">
                  {formatGhs(auction.currentBidGhs)}
                </p>
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}

import type { Metadata } from "next";
import Link from "next/link";
import { SaveProductButton } from "@/components/product/SaveProductButton";
import { EmptyState } from "@/components/ui/EmptyState";
import { auth } from "@/auth";
import { formatGhs } from "@/lib/currency";
import { getProduct } from "@/lib/data/products";
import { getSeller } from "@/lib/data/sellers";
import { listAllStreams } from "@/lib/data/stream-registry";
import { getUserById } from "@/lib/data/users";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Auctions",
};

export default async function AuctionsPage() {
  const streams = (await listAllStreams()).filter((s) => s.auction);
  const session = await auth();
  const user = session?.user?.id
    ? await getUserById(session.user.id)
    : undefined;
  const saved = new Set(user?.savedProductIds ?? []);

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
        Auctions
      </h1>
      <p className="mt-2 text-sm text-hubsom-ink/65">
        Live bidding from Hubsom shows — open an auction when you go live.
      </p>

      <div className="mt-5 space-y-3">
        {!streams.length && (
          <EmptyState
            title="No open auctions"
            body="Enable auction when starting a live show."
            actionHref="/seller/go-live"
            actionLabel="Go live"
          />
        )}
        {await Promise.all(
          streams.map(async (stream) => {
            const auction = stream.auction!;
            const product = await getProduct(auction.productId);
            const seller = await getSeller(stream.sellerId);
            return (
              <div
                key={auction.id}
                className="flex items-start gap-3 rounded-2xl border border-hubsom-forest/10 bg-white/80 p-4"
              >
                <Link href={`/live/${stream.id}`} className="min-w-0 flex-1">
                  <p className="text-[10px] font-bold uppercase tracking-[0.14em] text-hubsom-gold">
                    {auction.status}
                  </p>
                  <p className="mt-1 font-display text-lg font-bold text-hubsom-ink">
                    {product?.name ?? "Auction item"}
                  </p>
                  <p className="mt-1 text-sm text-hubsom-ink/65">
                    {seller?.name ?? "Seller"} · current{" "}
                    <span className="font-bold text-hubsom-forest">
                      {formatGhs(auction.currentBidGhs)}
                    </span>
                  </p>
                </Link>
                {product ? (
                  <SaveProductButton
                    productId={product.id}
                    initialSaved={saved.has(product.id)}
                    size="icon"
                    variant="default"
                    className="shrink-0"
                  />
                ) : null}
              </div>
            );
          }),
        )}
      </div>
    </div>
  );
}

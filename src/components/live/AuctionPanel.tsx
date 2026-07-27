"use client";

import { useEffect, useState } from "react";
import { useSession } from "next-auth/react";
import { Gavel } from "lucide-react";
import { Countdown } from "@/components/ui/Countdown";
import { formatGhs } from "@/lib/currency";
import type { LiveAuction, Product } from "@/types";

export function AuctionPanel({
  auction,
  product,
  onAuctionChange,
}: {
  auction: LiveAuction;
  product?: Product;
  onAuctionChange?: (auction: LiveAuction) => void;
}) {
  const { data: session } = useSession();
  const [current, setCurrent] = useState(auction);
  const [bidding, setBidding] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const ended = new Date(current.endsAt).getTime() <= Date.now();

  useEffect(() => {
    setCurrent(auction);
  }, [auction]);

  async function placeBid() {
    setBidding(true);
    setToast(null);
    try {
      const amount =
        Math.round((current.currentBidGhs + current.minIncrementGhs) * 100) /
        100;
      const res = await fetch(`/api/auctions/${current.id}/bid`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "same-origin",
        body: JSON.stringify({
          amountGhs: amount,
          bidder: session?.user?.name || undefined,
        }),
      });
      const data = (await res.json()) as {
        error?: string;
        currentBidGhs?: number;
        bidderCount?: number;
        highestBidder?: string;
        auction?: LiveAuction;
        endsAt?: string;
        minIncrementGhs?: number;
        status?: LiveAuction["status"];
      };
      if (!res.ok) {
        setToast(data.error ?? "Bid failed");
        if (data.auction) {
          setCurrent(data.auction);
          onAuctionChange?.(data.auction);
        }
        return;
      }

      const next: LiveAuction = data.auction ?? {
        ...current,
        currentBidGhs: data.currentBidGhs ?? amount,
        bidderCount: data.bidderCount ?? current.bidderCount + 1,
        highestBidder: data.highestBidder,
        endsAt: data.endsAt ?? current.endsAt,
        minIncrementGhs: data.minIncrementGhs ?? current.minIncrementGhs,
        status: data.status ?? current.status,
      };
      setCurrent(next);
      onAuctionChange?.(next);
      setToast("You're the high bidder");
    } catch {
      setToast("Network error — try again");
    } finally {
      setBidding(false);
    }
  }

  const nextBid =
    Math.round((current.currentBidGhs + current.minIncrementGhs) * 100) / 100;

  return (
    <div className="rounded-2xl border border-hubsom-gold/40 bg-gradient-to-br from-hubsom-night/90 to-hubsom-forest/90 p-4 text-white shadow-lg">
      <div className="flex items-center justify-between gap-3">
        <div className="inline-flex items-center gap-2 text-xs font-bold uppercase tracking-[0.16em] text-hubsom-gold">
          <Gavel className="h-4 w-4" />
          Live auction
        </div>
        <div className="rounded-md bg-hubsom-live px-2 py-1 text-xs font-bold tabular-nums">
          {ended ? "Ended" : <Countdown endsAt={current.endsAt} />}
        </div>
      </div>
      <p className="mt-3 font-display text-xl font-semibold">
        {product?.name ?? "Auction item"}
      </p>
      <div className="mt-3 grid grid-cols-2 gap-3 text-sm">
        <div>
          <p className="text-white/55">Current bid</p>
          <p className="text-lg font-bold text-hubsom-sun">
            {formatGhs(current.currentBidGhs)}
          </p>
        </div>
        <div>
          <p className="text-white/55">Bidders</p>
          <p className="text-lg font-bold">{current.bidderCount}</p>
        </div>
      </div>
      <p className="mt-2 text-xs text-white/60">
        High bidder: {current.highestBidder ?? "—"} · Min +
        {formatGhs(current.minIncrementGhs)}
      </p>
      {product ? (
        <p className="mt-1 text-[11px] text-white/45">
          Catalog Buy Now {formatGhs(product.priceGhs)} · bidding uses live bid
          price
        </p>
      ) : null}
      <button
        type="button"
        disabled={bidding || ended || current.status === "sold"}
        onClick={() => void placeBid()}
        className="mt-4 w-full rounded-xl bg-hubsom-gold py-3 text-sm font-bold text-hubsom-ink transition hover:bg-hubsom-sun disabled:opacity-60"
      >
        {ended
          ? "Auction ended"
          : bidding
            ? "Placing…"
            : `Bid ${formatGhs(nextBid)}`}
      </button>
      {toast && (
        <p
          className={`mt-2 text-center text-xs ${
            toast.toLowerCase().includes("high bidder")
              ? "text-hubsom-mint"
              : "text-hubsom-sun"
          }`}
        >
          {toast}
        </p>
      )}
    </div>
  );
}

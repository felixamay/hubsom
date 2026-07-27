"use client";

import { useState } from "react";
import { Gavel } from "lucide-react";
import { Countdown } from "@/components/ui/Countdown";
import { formatGhs } from "@/lib/currency";
import type { LiveAuction, Product } from "@/types";

export function AuctionPanel({
  auction,
  product,
}: {
  auction: LiveAuction;
  product?: Product;
}) {
  const [current, setCurrent] = useState(auction);
  const [bidding, setBidding] = useState(false);
  const [toast, setToast] = useState<string | null>(null);

  async function placeBid() {
    setBidding(true);
    setToast(null);
    try {
      const amount = current.currentBidGhs + current.minIncrementGhs;
      const res = await fetch(`/api/auctions/${current.id}/bid`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ amountGhs: amount, bidder: "You" }),
      });
      const data = await res.json();
      if (!res.ok) {
        setToast(data.error ?? "Bid failed");
        return;
      }
      setCurrent((prev) => ({
        ...prev,
        currentBidGhs: data.currentBidGhs,
        bidderCount: data.bidderCount,
        highestBidder: data.highestBidder,
      }));
      setToast("You're the high bidder");
    } finally {
      setBidding(false);
    }
  }

  return (
    <div className="rounded-2xl border border-hubsom-gold/40 bg-gradient-to-br from-hubsom-night/90 to-hubsom-forest/90 p-4 text-white shadow-lg">
      <div className="flex items-center justify-between gap-3">
        <div className="inline-flex items-center gap-2 text-xs font-bold uppercase tracking-[0.16em] text-hubsom-gold">
          <Gavel className="h-4 w-4" />
          Live auction
        </div>
        <div className="rounded-md bg-hubsom-live px-2 py-1 text-xs font-bold tabular-nums">
          <Countdown endsAt={current.endsAt} />
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
      <button
        type="button"
        disabled={bidding}
        onClick={placeBid}
        className="mt-4 w-full rounded-xl bg-hubsom-gold py-3 text-sm font-bold text-hubsom-ink transition hover:bg-hubsom-sun disabled:opacity-60"
      >
        {bidding
          ? "Placing…"
          : `Bid ${formatGhs(current.currentBidGhs + current.minIncrementGhs)}`}
      </button>
      {toast && <p className="mt-2 text-center text-xs text-hubsom-mint">{toast}</p>}
    </div>
  );
}

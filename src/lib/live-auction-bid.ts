import type { LiveAuction } from "../types";

export type AuctionBidInput = {
  auction: LiveAuction;
  amountGhs?: number;
  bidderName: string;
  bidderId?: string;
  bidderEmail?: string;
  nowMs?: number;
};

export type AuctionBidResult =
  | { ok: true; auction: LiveAuction }
  | {
      ok: false;
      error: string;
      auction: LiveAuction;
      minNextGhs?: number;
    };

function roundGhs(value: number): number {
  return Math.round(value * 100) / 100;
}

export function auctionHasWinner(auction: LiveAuction): boolean {
  return Boolean(
    auction.highestBidderId ||
      auction.highestBidder ||
      (auction.bidderCount ?? 0) > 0,
  );
}

export function minNextBidGhs(auction: LiveAuction): number {
  return roundGhs(auction.currentBidGhs + auction.minIncrementGhs);
}

/**
 * Apply one bid to a live lot.
 *
 * A late bid must not rewrite a winning lot to `unsold` — that discarded
 * the high bidder and prevented winner-order settlement.
 */
export function applyAuctionBid(input: AuctionBidInput): AuctionBidResult {
  const { auction, bidderName, bidderId, bidderEmail } = input;
  const now = input.nowMs ?? Date.now();

  if (auction.status !== "open" && auction.status !== "closing") {
    return {
      ok: false,
      error: "This auction is no longer accepting bids",
      auction,
    };
  }

  const endsAt = new Date(auction.endsAt).getTime();
  if (!Number.isFinite(endsAt) || endsAt <= now) {
    if (auctionHasWinner(auction)) {
      return { ok: false, error: "Auction has ended", auction };
    }
    return {
      ok: false,
      error: "Auction has ended",
      auction: { ...auction, status: "unsold" },
    };
  }

  const minNext = minNextBidGhs(auction);
  const amount =
    input.amountGhs != null && Number.isFinite(Number(input.amountGhs))
      ? roundGhs(Number(input.amountGhs))
      : minNext;

  if (amount < minNext) {
    return {
      ok: false,
      error: `Bid must be at least GHS ${minNext.toFixed(2)}`,
      auction,
      minNextGhs: minNext,
    };
  }

  // Soft close: a bid in the last 3s nudges the clock so in-flight bids settle.
  let nextEndsAt = auction.endsAt;
  if (endsAt - now < 3_000) {
    nextEndsAt = new Date(now + 5_000).toISOString();
  }

  return {
    ok: true,
    auction: {
      ...auction,
      currentBidGhs: amount,
      bidderCount: auction.bidderCount + 1,
      highestBidder: bidderName,
      highestBidderId: bidderId,
      highestBidderEmail: bidderEmail,
      endsAt: nextEndsAt,
      status: "open",
    },
  };
}

import type { LiveAuction } from "@/types";

export function minNextBidGhs(auction: LiveAuction): number {
  return Math.round((auction.currentBidGhs + auction.minIncrementGhs) * 100) / 100;
}

export function roundBidGhs(amount: number): number {
  return Math.round(amount * 100) / 100;
}

export type BidDecision =
  | { kind: "closed"; error: string }
  | { kind: "expired"; error: string; auction: LiveAuction }
  | {
      kind: "too_low";
      error: string;
      minNextGhs: number;
      currentBidGhs: number;
    }
  | { kind: "accept"; auction: LiveAuction };

/**
 * Pure bid rules. Caller must re-run this against a freshly loaded auction
 * under a lock so concurrent bids cannot overwrite a higher amount.
 */
export function decideAuctionBid(input: {
  auction: LiveAuction;
  amountGhs?: number;
  bidderName: string;
  bidderUserId: string;
  nowMs?: number;
}): BidDecision {
  const { auction } = input;
  if (auction.status !== "open" && auction.status !== "closing") {
    return {
      kind: "closed",
      error: "This auction is no longer accepting bids",
    };
  }

  const nowMs = input.nowMs ?? Date.now();
  if (new Date(auction.endsAt).getTime() <= nowMs) {
    const hadBids =
      auction.bidderCount > 0 || Boolean(auction.highestBidderId);
    return {
      kind: "expired",
      error: "Auction has ended",
      // Late bids must not wipe an existing high bidder as "unsold".
      auction: {
        ...auction,
        status: hadBids ? "closing" : "unsold",
      },
    };
  }

  const minNext = minNextBidGhs(auction);
  const amount =
    input.amountGhs != null && Number.isFinite(Number(input.amountGhs))
      ? roundBidGhs(Number(input.amountGhs))
      : minNext;

  if (amount < minNext) {
    return {
      kind: "too_low",
      error: `Bid must be at least GHS ${minNext.toFixed(2)}`,
      minNextGhs: minNext,
      currentBidGhs: auction.currentBidGhs,
    };
  }

  return {
    kind: "accept",
    auction: {
      ...auction,
      currentBidGhs: amount,
      bidderCount: auction.bidderCount + 1,
      highestBidder: input.bidderName,
      highestBidderId: input.bidderUserId,
      status: "open",
    },
  };
}

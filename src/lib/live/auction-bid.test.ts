import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { LiveAuction } from "@/types";
import { decideAuctionBid, minNextBidGhs } from "./auction-bid.ts";

function openAuction(overrides: Partial<LiveAuction> = {}): LiveAuction {
  return {
    id: "auction-1",
    productId: "prod-1",
    startingBidGhs: 50,
    currentBidGhs: 100,
    minIncrementGhs: 10,
    endsAt: new Date(Date.now() + 60_000).toISOString(),
    bidderCount: 2,
    highestBidder: "Ama",
    highestBidderId: "user-ama",
    status: "open",
    ...overrides,
  };
}

describe("decideAuctionBid", () => {
  it("rejects bids below the current high plus increment", () => {
    const auction = openAuction();
    const decision = decideAuctionBid({
      auction,
      amountGhs: 105,
      bidderName: "Kojo",
      bidderUserId: "user-kojo",
    });
    assert.equal(decision.kind, "too_low");
    if (decision.kind !== "too_low") return;
    assert.equal(decision.minNextGhs, minNextBidGhs(auction));
    assert.equal(decision.currentBidGhs, 100);
  });

  it("records the authenticated bidder, not a client-supplied name", () => {
    const decision = decideAuctionBid({
      auction: openAuction(),
      amountGhs: 110,
      bidderName: "Session User",
      bidderUserId: "user-session",
    });
    assert.equal(decision.kind, "accept");
    if (decision.kind !== "accept") return;
    assert.equal(decision.auction.highestBidder, "Session User");
    assert.equal(decision.auction.highestBidderId, "user-session");
    assert.equal(decision.auction.currentBidGhs, 110);
    assert.equal(decision.auction.bidderCount, 3);
  });

  it("does not mark an auction with bids as unsold when the clock expires", () => {
    const decision = decideAuctionBid({
      auction: openAuction({
        endsAt: new Date(Date.now() - 1_000).toISOString(),
      }),
      amountGhs: 200,
      bidderName: "Late",
      bidderUserId: "user-late",
      nowMs: Date.now(),
    });
    assert.equal(decision.kind, "expired");
    if (decision.kind !== "expired") return;
    assert.equal(decision.auction.status, "closing");
    assert.equal(decision.auction.highestBidderId, "user-ama");
    assert.equal(decision.auction.currentBidGhs, 100);
  });

  it("marks a bid-less expired auction as unsold", () => {
    const decision = decideAuctionBid({
      auction: openAuction({
        bidderCount: 0,
        highestBidder: undefined,
        highestBidderId: undefined,
        currentBidGhs: 50,
        endsAt: new Date(Date.now() - 1_000).toISOString(),
      }),
      bidderName: "Late",
      bidderUserId: "user-late",
    });
    assert.equal(decision.kind, "expired");
    if (decision.kind !== "expired") return;
    assert.equal(decision.auction.status, "unsold");
  });

  it("rejects a stale lower bid when a higher bid already landed", () => {
    const afterHigherBid = openAuction({
      currentBidGhs: 120,
      bidderCount: 3,
      highestBidder: "Ama",
      highestBidderId: "user-ama",
    });
    const stale = decideAuctionBid({
      auction: afterHigherBid,
      amountGhs: 110,
      bidderName: "Kojo",
      bidderUserId: "user-kojo",
    });
    assert.equal(stale.kind, "too_low");
  });
});

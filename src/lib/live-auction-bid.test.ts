import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { LiveAuction } from "../types/index.ts";
import { applyAuctionBid, auctionHasWinner } from "./live-auction-bid.ts";

function openLot(overrides: Partial<LiveAuction> = {}): LiveAuction {
  return {
    id: "auction-1",
    productId: "prod-1",
    startingBidGhs: 50,
    currentBidGhs: 150,
    minIncrementGhs: 10,
    endsAt: new Date(Date.now() + 20_000).toISOString(),
    bidderCount: 2,
    highestBidder: "Alice",
    highestBidderId: "user-alice",
    highestBidderEmail: "alice@hubsom.test",
    status: "open",
    ...overrides,
  };
}

describe("applyAuctionBid", () => {
  it("records the signed-in bidder id and email on a valid bid", () => {
    const result = applyAuctionBid({
      auction: openLot(),
      amountGhs: 160,
      bidderName: "Bob",
      bidderId: "user-bob",
      bidderEmail: "bob@hubsom.test",
    });
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.auction.currentBidGhs, 160);
    assert.equal(result.auction.highestBidder, "Bob");
    assert.equal(result.auction.highestBidderId, "user-bob");
    assert.equal(result.auction.highestBidderEmail, "bob@hubsom.test");
    assert.equal(result.auction.bidderCount, 3);
    assert.equal(result.auction.status, "open");
  });

  it("does not mark a winning lot unsold after the clock hits zero", () => {
    const winner = openLot({
      endsAt: new Date(Date.now() - 500).toISOString(),
    });
    const result = applyAuctionBid({
      auction: winner,
      amountGhs: 160,
      bidderName: "Bob",
      bidderId: "user-bob",
    });
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error, "Auction has ended");
    assert.equal(result.auction.status, "open");
    assert.equal(result.auction.highestBidder, "Alice");
    assert.equal(result.auction.highestBidderId, "user-alice");
    assert.equal(result.auction.currentBidGhs, 150);
    assert.equal(auctionHasWinner(result.auction), true);
  });

  it("marks an expired lot unsold only when nobody bid", () => {
    const empty = openLot({
      currentBidGhs: 50,
      bidderCount: 0,
      highestBidder: undefined,
      highestBidderId: undefined,
      highestBidderEmail: undefined,
      endsAt: new Date(Date.now() - 500).toISOString(),
    });
    const result = applyAuctionBid({
      auction: empty,
      amountGhs: 60,
      bidderName: "Bob",
      bidderId: "user-bob",
    });
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.auction.status, "unsold");
    assert.equal(result.auction.highestBidder, undefined);
  });

  it("rejects a bid below the minimum increment", () => {
    const result = applyAuctionBid({
      auction: openLot(),
      amountGhs: 155,
      bidderName: "Bob",
      bidderId: "user-bob",
    });
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.match(result.error, /at least GHS 160/);
    assert.equal(result.auction.highestBidderId, "user-alice");
  });
});

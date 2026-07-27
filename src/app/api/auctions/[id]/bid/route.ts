import { NextResponse } from "next/server";
import {
  findStreamByAuctionId,
  patchStream,
} from "@/lib/data/stream-registry";

export async function POST(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const stream = await findStreamByAuctionId(id);
  if (!stream?.auction) {
    return NextResponse.json({ error: "Auction not found" }, { status: 404 });
  }

  const body = (await request.json()) as {
    amountGhs?: number;
    bidder?: string;
  };

  const auction = stream.auction;
  const amount =
    body.amountGhs ?? auction.currentBidGhs + auction.minIncrementGhs;
  if (amount < auction.currentBidGhs + auction.minIncrementGhs) {
    return NextResponse.json(
      {
        error: `Bid must be at least GHS ${auction.currentBidGhs + auction.minIncrementGhs}`,
      },
      { status: 400 },
    );
  }

  const nextAuction = {
    ...auction,
    currentBidGhs: amount,
    bidderCount: auction.bidderCount + 1,
    highestBidder: body.bidder?.trim() || "You",
  };

  await patchStream(stream.id, { auction: nextAuction });

  return NextResponse.json({
    auctionId: id,
    currentBidGhs: nextAuction.currentBidGhs,
    bidderCount: nextAuction.bidderCount,
    highestBidder: nextAuction.highestBidder,
    endsAt: nextAuction.endsAt,
    minIncrementGhs: nextAuction.minIncrementGhs,
    status: nextAuction.status,
  });
}

import { NextResponse } from "next/server";
import { STREAMS } from "@/lib/data/streams";

const auctionState = new Map<
  string,
  { currentBidGhs: number; bidderCount: number; highestBidder: string }
>();

export async function POST(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const stream = STREAMS.find((s) => s.auction?.id === id);
  if (!stream?.auction) {
    return NextResponse.json({ error: "Auction not found" }, { status: 404 });
  }

  const body = (await request.json()) as {
    amountGhs?: number;
    bidder?: string;
  };

  const current =
    auctionState.get(id) ??
    {
      currentBidGhs: stream.auction.currentBidGhs,
      bidderCount: stream.auction.bidderCount,
      highestBidder: stream.auction.highestBidder ?? "—",
    };

  const amount = body.amountGhs ?? current.currentBidGhs + stream.auction.minIncrementGhs;
  if (amount < current.currentBidGhs + stream.auction.minIncrementGhs) {
    return NextResponse.json(
      {
        error: `Bid must be at least GHS ${current.currentBidGhs + stream.auction.minIncrementGhs}`,
      },
      { status: 400 },
    );
  }

  const next = {
    currentBidGhs: amount,
    bidderCount: current.bidderCount + 1,
    highestBidder: body.bidder?.trim() || "You",
  };
  auctionState.set(id, next);

  return NextResponse.json({
    auctionId: id,
    ...next,
    endsAt: stream.auction.endsAt,
    minIncrementGhs: stream.auction.minIncrementGhs,
    status: "open",
  });
}

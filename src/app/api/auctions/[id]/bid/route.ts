import { NextResponse } from "next/server";
import { auth } from "@/auth";
import { placeAuctionBid } from "@/lib/data/stream-registry";

export async function POST(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in to place a bid" }, { status: 401 });
  }

  const { id } = await context.params;

  let body: { amountGhs?: number } = {};
  try {
    body = (await request.json()) as { amountGhs?: number };
  } catch {
    body = {};
  }

  const bidderName =
    session.user.name?.trim() ||
    session.user.email?.split("@")[0] ||
    "Bidder";

  const result = await placeAuctionBid({
    auctionId: id,
    amountGhs: body.amountGhs,
    bidderName,
    bidderUserId: session.user.id,
  });

  if (!result.ok) {
    return NextResponse.json(
      {
        error: result.error,
        auction: result.auction,
        minNextGhs: result.minNextGhs,
        currentBidGhs: result.currentBidGhs,
      },
      { status: result.status },
    );
  }

  const auction = result.auction;
  return NextResponse.json({
    auctionId: id,
    streamId: result.stream.id,
    currentBidGhs: auction.currentBidGhs,
    bidderCount: auction.bidderCount,
    highestBidder: auction.highestBidder,
    highestBidderId: auction.highestBidderId,
    endsAt: auction.endsAt,
    minIncrementGhs: auction.minIncrementGhs,
    status: auction.status,
    auction,
  });
}

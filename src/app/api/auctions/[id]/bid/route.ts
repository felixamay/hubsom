import { NextResponse } from "next/server";
import { auth } from "@/auth";
import {
  findStreamByAuctionId,
  patchStream,
} from "@/lib/data/stream-registry";
import { applyAuctionBid } from "@/lib/live-auction-bid";

export async function POST(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in to place a bid" }, { status: 401 });
  }

  const { id } = await context.params;
  const stream = await findStreamByAuctionId(id);
  if (!stream?.auction) {
    return NextResponse.json({ error: "Auction not found" }, { status: 404 });
  }

  let body: { amountGhs?: number; bidder?: string } = {};
  try {
    body = (await request.json()) as { amountGhs?: number; bidder?: string };
  } catch {
    body = {};
  }

  const bidderName =
    session.user.name?.trim() ||
    body.bidder?.trim() ||
    session.user.email?.split("@")[0] ||
    "Bidder";

  const result = applyAuctionBid({
    auction: stream.auction,
    amountGhs: body.amountGhs,
    bidderName,
    bidderId: session.user.id,
    bidderEmail: session.user.email ?? undefined,
  });

  if (!result.ok) {
    if (result.auction !== stream.auction) {
      await patchStream(stream.id, { auction: result.auction });
    }
    return NextResponse.json(
      {
        error: result.error,
        auction: result.auction,
        minNextGhs: result.minNextGhs,
        currentBidGhs: result.auction.currentBidGhs,
      },
      { status: 400 },
    );
  }

  const updated = await patchStream(stream.id, { auction: result.auction });
  const auction = updated?.auction ?? result.auction;

  return NextResponse.json({
    auctionId: id,
    streamId: stream.id,
    currentBidGhs: auction.currentBidGhs,
    bidderCount: auction.bidderCount,
    highestBidder: auction.highestBidder,
    highestBidderId: auction.highestBidderId,
    highestBidderEmail: auction.highestBidderEmail,
    endsAt: auction.endsAt,
    minIncrementGhs: auction.minIncrementGhs,
    status: auction.status,
    auction,
  });
}

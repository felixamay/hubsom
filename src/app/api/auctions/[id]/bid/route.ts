import { NextResponse } from "next/server";
import { auth } from "@/auth";
import {
  findStreamByAuctionId,
  patchStream,
} from "@/lib/data/stream-registry";

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

  const auction = stream.auction;
  if (auction.status !== "open" && auction.status !== "closing") {
    return NextResponse.json(
      { error: "This auction is no longer accepting bids" },
      { status: 400 },
    );
  }

  if (new Date(auction.endsAt).getTime() <= Date.now()) {
    const closed = {
      ...auction,
      status: "unsold" as const,
    };
    await patchStream(stream.id, { auction: closed });
    return NextResponse.json(
      { error: "Auction has ended", auction: closed },
      { status: 400 },
    );
  }

  const minNext =
    Math.round((auction.currentBidGhs + auction.minIncrementGhs) * 100) / 100;
  const amount =
    body.amountGhs != null && Number.isFinite(Number(body.amountGhs))
      ? Math.round(Number(body.amountGhs) * 100) / 100
      : minNext;

  if (amount < minNext) {
    return NextResponse.json(
      {
        error: `Bid must be at least GHS ${minNext.toFixed(2)}`,
        minNextGhs: minNext,
        currentBidGhs: auction.currentBidGhs,
      },
      { status: 400 },
    );
  }

  const bidderName =
    body.bidder?.trim() ||
    session.user.name?.trim() ||
    session.user.email?.split("@")[0] ||
    "Bidder";

  const nextAuction = {
    ...auction,
    currentBidGhs: amount,
    bidderCount: auction.bidderCount + 1,
    highestBidder: bidderName,
    status: "open" as const,
  };

  const updated = await patchStream(stream.id, { auction: nextAuction });

  return NextResponse.json({
    auctionId: id,
    streamId: stream.id,
    currentBidGhs: nextAuction.currentBidGhs,
    bidderCount: nextAuction.bidderCount,
    highestBidder: nextAuction.highestBidder,
    endsAt: nextAuction.endsAt,
    minIncrementGhs: nextAuction.minIncrementGhs,
    status: nextAuction.status,
    auction: updated?.auction ?? nextAuction,
  });
}

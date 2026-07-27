import { NextResponse } from "next/server";
import { createLiveStream, listAllStreams } from "@/lib/data/stream-registry";
import { getProduct } from "@/lib/data/products";
import { getSeller } from "@/lib/data/sellers";

export async function GET() {
  const streams = (await listAllStreams()).map((stream) => ({
    ...stream,
    seller: getSeller(stream.sellerId) ?? null,
  }));
  return NextResponse.json({ streams });
}

export async function POST(request: Request) {
  const body = (await request.json()) as {
    title?: string;
    description?: string;
    sellerId?: string;
    productIds?: string[];
    pinnedProductId?: string;
    auctionProductId?: string | null;
    multiHost?: boolean;
    enableRecording?: boolean;
    startingBidGhs?: number;
  };

  const productIds = (body.productIds ?? []).filter((id) => Boolean(getProduct(id)));
  if (!productIds.length) {
    return NextResponse.json(
      { error: "Select at least one product for the show" },
      { status: 400 },
    );
  }

  const stream = await createLiveStream({
    title: body.title?.trim() || "Hubsom Live Show",
    description: body.description,
    sellerId: body.sellerId,
    productIds,
    pinnedProductId: body.pinnedProductId,
    auctionProductId: body.auctionProductId || undefined,
    multiHost: body.multiHost,
    enableRecording: body.enableRecording,
    startingBidGhs: body.startingBidGhs,
  });

  return NextResponse.json({ stream }, { status: 201 });
}

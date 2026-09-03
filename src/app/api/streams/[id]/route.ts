import { NextResponse } from "next/server";
import { getProduct } from "@/lib/data/products";
import { getSeller } from "@/lib/data/sellers";
import { getStreamById, patchStream } from "@/lib/data/stream-registry";

export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const stream = await getStreamById(id);
  if (!stream) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }

  const products = (
    await Promise.all(stream.productIds.map((pid) => getProduct(pid)))
  ).filter(Boolean);

  return NextResponse.json({
    stream,
    seller: (await getSeller(stream.sellerId)) ?? null,
    products,
    capabilities: {
      multiHost: stream.isMultiHost,
      recording: stream.replayAvailable,
      auctions: Boolean(stream.auction),
      liveCart: true,
      reactions: true,
      chat: true,
      inventorySync: true,
    },
  });
}

export async function PATCH(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const body = (await request.json()) as Record<string, unknown>;
  const stream = await patchStream(id, body);
  if (!stream) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }
  return NextResponse.json({ stream });
}

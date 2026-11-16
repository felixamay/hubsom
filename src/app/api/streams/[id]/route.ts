import { NextResponse } from "next/server";
import { auth } from "@/auth";
import { getProduct } from "@/lib/data/products";
import { getSeller } from "@/lib/data/sellers";
import { getStreamById, patchStream } from "@/lib/data/stream-registry";
import { isStreamHost } from "@/lib/live/host-auth";
import type { LiveStream } from "@/types";

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
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { id } = await context.params;
  const existing = await getStreamById(id);
  if (!existing) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }

  if (!(await isStreamHost(session.user.id, existing))) {
    return NextResponse.json(
      { error: "Only the host can update this live show" },
      { status: 403 },
    );
  }

  let body: Record<string, unknown> = {};
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    body = {};
  }

  const patch: Partial<LiveStream> = {};
  if (typeof body.pinnedProductId === "string") {
    if (!existing.productIds.includes(body.pinnedProductId)) {
      return NextResponse.json(
        { error: "Product is not part of this show" },
        { status: 400 },
      );
    }
    patch.pinnedProductId = body.pinnedProductId;
  }
  if (body.recording === true || body.replayAvailable === true) {
    patch.replayAvailable = true;
  }

  if (Object.keys(patch).length === 0) {
    return NextResponse.json({ stream: existing });
  }

  const stream = await patchStream(id, patch);
  return NextResponse.json({ stream });
}

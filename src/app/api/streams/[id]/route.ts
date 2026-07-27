import { NextResponse } from "next/server";
import { getProduct } from "@/lib/data/products";
import { getSeller } from "@/lib/data/sellers";
import { getStreamById, patchStream } from "@/lib/data/stream-registry";

export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const stream = getStreamById(id);
  if (!stream) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }

  const seller = getSeller(stream.sellerId);
  const products = stream.productIds
    .map((pid) => getProduct(pid))
    .filter(Boolean);

  return NextResponse.json({
    stream,
    seller,
    products,
    capabilities: {
      ultraLowLatency: true,
      adaptiveBitrate: true,
      hd: true,
      fullHd: true,
      realTimeChat: true,
      liveReactions: true,
      productPinning: true,
      liveCart: true,
      oneTapCheckout: true,
      liveAuctions: true,
      multiHost: stream.isMultiHost,
      guestSellers: stream.hosts.some((h) => h.role === "guest"),
      moderatorControls: stream.hosts.some((h) => h.role === "moderator"),
      pictureInPicture: true,
      streamRecording: true,
      liveReplay: stream.replayAvailable,
      aiModeration: true,
      pushNotifications: true,
      viewerAnalytics: true,
      sellerAnalytics: true,
      realtimeInventorySync: true,
      autoScaling: true,
      concurrentViewerTarget: 10000,
    },
  });
}

export async function PATCH(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const body = (await request.json()) as {
    pinnedProductId?: string;
    recording?: boolean;
    status?: "live" | "ended" | "replay";
    viewerCount?: number;
  };

  const patch: Record<string, unknown> = {};
  if (body.pinnedProductId) patch.pinnedProductId = body.pinnedProductId;
  if (typeof body.viewerCount === "number") patch.viewerCount = body.viewerCount;
  if (body.recording) {
    patch.replayAvailable = true;
  }
  if (body.status === "ended") {
    patch.status = "ended";
    patch.endedAt = new Date().toISOString();
    patch.replayAvailable = true;
  }
  if (body.status === "replay") {
    patch.status = "replay";
    patch.replayAvailable = true;
  }

  const stream = patchStream(id, patch);
  if (!stream) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }
  return NextResponse.json({ stream });
}

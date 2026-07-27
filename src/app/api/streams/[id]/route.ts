import { NextResponse } from "next/server";
import { getStream } from "@/lib/data/streams";
import { getProduct } from "@/lib/data/products";
import { getSeller } from "@/lib/data/sellers";

export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const stream = getStream(id);
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

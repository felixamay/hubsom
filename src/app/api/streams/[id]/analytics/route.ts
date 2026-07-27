import { NextResponse } from "next/server";
import {
  SELLER_ANALYTICS,
  VIEWER_ANALYTICS,
} from "@/lib/data/streams";
import { getStreamById } from "@/lib/data/stream-registry";

export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const stream = await getStreamById(id);
  if (!stream) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }

  return NextResponse.json({
    viewer:
      VIEWER_ANALYTICS.find((a) => a.streamId === id) ?? {
        streamId: id,
        concurrent: stream.viewerCount,
        avgWatchSeconds: 0,
        chatMessages: 0,
        reactions: 0,
        checkouts: 0,
        conversionRate: 0,
      },
    seller:
      SELLER_ANALYTICS.find((a) => a.streamId === id) ?? {
        streamId: id,
        revenueGhs: 0,
        unitsSold: 0,
        uniqueBuyers: 0,
        peakConcurrent: stream.peakViewers,
        avgLatencyMs: stream.latencyMs,
        inventorySyncEvents: 0,
      },
  });
}

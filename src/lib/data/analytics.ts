import { getOrderStats, listOrders } from "@/lib/data/orders";
import { listAllStreams } from "@/lib/data/stream-registry";
import type { SellerAnalytics, ViewerAnalytics } from "@/types";

export async function getPlatformAnalytics(): Promise<{
  seller: SellerAnalytics;
  viewer: ViewerAnalytics;
}> {
  const [stats, streams, orders] = await Promise.all([
    getOrderStats(),
    listAllStreams(),
    listOrders(),
  ]);

  const live = streams.filter((s) => s.status === "live");
  const peak = Math.max(0, ...streams.map((s) => s.peakViewers), 0);
  const concurrent = live.reduce((n, s) => n + s.viewerCount, 0);
  const checkouts = orders.length;
  const conversionRate =
    concurrent > 0 ? Math.min(1, checkouts / Math.max(concurrent, 1)) : 0;

  const seller: SellerAnalytics = {
    streamId: live[0]?.id ?? "—",
    revenueGhs: stats.revenueGhs,
    unitsSold: stats.unitsSold,
    uniqueBuyers: stats.uniqueBuyers,
    peakConcurrent: peak,
    avgLatencyMs: live[0]?.latencyMs ?? 0,
    inventorySyncEvents: stats.unitsSold,
  };

  const viewer: ViewerAnalytics = {
    streamId: live[0]?.id ?? "—",
    concurrent,
    avgWatchSeconds: 0,
    chatMessages: 0,
    reactions: 0,
    checkouts,
    conversionRate,
  };

  return { seller, viewer };
}

export async function getStreamAnalytics(streamId: string) {
  const orders = (await listOrders()).filter((o) => o.streamId === streamId);
  const stream = (await listAllStreams()).find((s) => s.id === streamId);
  const revenueGhs = orders.reduce((n, o) => n + o.subtotalGhs, 0);
  const unitsSold = orders.reduce(
    (n, o) => n + o.lines.reduce((x, l) => x + l.quantity, 0),
    0,
  );

  return {
    viewer: {
      streamId,
      concurrent: stream?.viewerCount ?? 0,
      avgWatchSeconds: 0,
      chatMessages: 0,
      reactions: 0,
      checkouts: orders.length,
      conversionRate:
        (stream?.viewerCount ?? 0) > 0
          ? orders.length / Math.max(stream!.viewerCount, 1)
          : 0,
    } satisfies ViewerAnalytics,
    seller: {
      streamId,
      revenueGhs,
      unitsSold,
      uniqueBuyers: orders.length,
      peakConcurrent: stream?.peakViewers ?? 0,
      avgLatencyMs: stream?.latencyMs ?? 0,
      inventorySyncEvents: unitsSold,
    } satisfies SellerAnalytics,
  };
}

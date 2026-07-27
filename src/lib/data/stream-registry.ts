import type { LiveStream, ProductCategory, StreamHost } from "@/types";
import { STREAMS } from "@/lib/data/streams";
import { getProduct } from "@/lib/data/products";

const runtime = new Map<string, LiveStream>();

function seedFallback(id: string) {
  return STREAMS.find((s) => s.id === id);
}

export function listAllStreams(): LiveStream[] {
  const byId = new Map<string, LiveStream>();
  for (const s of STREAMS) byId.set(s.id, s);
  for (const s of runtime.values()) byId.set(s.id, s);
  return Array.from(byId.values()).sort((a, b) => {
    const rank = (s: LiveStream) =>
      s.status === "live" ? 0 : s.status === "scheduled" ? 1 : 2;
    return rank(a) - rank(b);
  });
}

export function getStreamById(id: string): LiveStream | undefined {
  return runtime.get(id) ?? seedFallback(id);
}

export function upsertStream(stream: LiveStream) {
  runtime.set(stream.id, stream);
  return stream;
}

export function patchStream(
  id: string,
  patch: Partial<LiveStream>,
): LiveStream | undefined {
  const current = getStreamById(id);
  if (!current) return undefined;
  const next = { ...current, ...patch };
  runtime.set(id, next);
  return next;
}

export interface CreateStreamInput {
  title: string;
  description?: string;
  sellerId?: string;
  productIds: string[];
  pinnedProductId?: string;
  auctionProductId?: string;
  multiHost?: boolean;
  enableRecording?: boolean;
  startingBidGhs?: number;
}

export function createLiveStream(input: CreateStreamInput): LiveStream {
  const id = `stream-${Date.now().toString(36)}`;
  const channelName = `hubsom_${id.replace(/[^a-z0-9]/gi, "_").toLowerCase()}`;
  const productIds = input.productIds.filter((pid) => Boolean(getProduct(pid)));
  const categories = Array.from(
    new Set(
      productIds
        .map((pid) => getProduct(pid)?.category)
        .filter(Boolean) as ProductCategory[],
    ),
  );

  const hosts: StreamHost[] = [
    {
      id: "host-you",
      name: "You",
      role: "host",
      avatar:
        "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?auto=format&fit=crop&w=200&q=80",
    },
  ];

  if (input.multiHost) {
    hosts.push({
      id: "guest-slot",
      name: "Guest slot open",
      role: "guest",
      avatar:
        "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=200&q=80",
    });
    hosts.push({
      id: "mod-slot",
      name: "Moderator",
      role: "moderator",
      avatar:
        "https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80",
    });
  }

  const auctionProductId = input.auctionProductId;
  const auction =
    auctionProductId && productIds.includes(auctionProductId)
      ? {
          id: `auction-${Date.now().toString(36)}`,
          productId: auctionProductId,
          startingBidGhs: input.startingBidGhs ?? 50,
          currentBidGhs: input.startingBidGhs ?? 50,
          minIncrementGhs: 10,
          endsAt: new Date(Date.now() + 1000 * 60 * 10).toISOString(),
          bidderCount: 0,
          status: "open" as const,
        }
      : undefined;

  const stream: LiveStream = {
    id,
    title: input.title.trim() || "Hubsom Live Show",
    description:
      input.description?.trim() ||
      "Live commerce on Hubsom — pin, bid, and one-tap checkout.",
    sellerId: input.sellerId ?? "seller-ama-market",
    status: "live",
    channelName,
    cover:
      getProduct(productIds[0])?.images[0] ??
      "https://images.unsplash.com/photo-1604719312566-8912e9227c6a?auto=format&fit=crop&w=1600&q=80",
    viewerCount: 1,
    peakViewers: 1,
    startedAt: new Date().toISOString(),
    productIds,
    pinnedProductId: input.pinnedProductId ?? productIds[0],
    hosts,
    auction,
    categories,
    latencyMs: 0,
    isMultiHost: Boolean(input.multiHost),
    replayAvailable: Boolean(input.enableRecording),
  };

  return upsertStream(stream);
}

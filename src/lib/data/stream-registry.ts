import { promises as fs } from "fs";
import path from "path";
import type { LiveStream, ProductCategory, StreamHost } from "@/types";
import { getProduct } from "@/lib/data/products";
import { ensureDefaultSeller } from "@/lib/data/sellers";

const DATA_DIR = path.join(process.cwd(), ".data");
const STORE_FILE = path.join(DATA_DIR, "live-streams.json");

type StoreShape = Record<string, LiveStream>;

async function ensureStore(): Promise<StoreShape> {
  try {
    await fs.mkdir(DATA_DIR, { recursive: true });
    const raw = await fs.readFile(STORE_FILE, "utf8");
    return JSON.parse(raw) as StoreShape;
  } catch {
    const empty: StoreShape = {};
    await fs.writeFile(STORE_FILE, JSON.stringify(empty, null, 2), "utf8");
    return empty;
  }
}

async function writeStore(store: StoreShape) {
  await fs.mkdir(DATA_DIR, { recursive: true });
  await fs.writeFile(STORE_FILE, JSON.stringify(store, null, 2), "utf8");
}

export async function listAllStreams(): Promise<LiveStream[]> {
  const store = await ensureStore();
  return Object.values(store).sort((a, b) => {
    const rank = (s: LiveStream) =>
      s.status === "live" ? 0 : s.status === "scheduled" ? 1 : 2;
    const r = rank(a) - rank(b);
    if (r !== 0) return r;
    return (b.startedAt ?? "").localeCompare(a.startedAt ?? "");
  });
}

export async function getStreamById(
  id: string,
): Promise<LiveStream | undefined> {
  const store = await ensureStore();
  return store[id];
}

export async function upsertStream(stream: LiveStream): Promise<LiveStream> {
  const store = await ensureStore();
  store[stream.id] = stream;
  await writeStore(store);
  return stream;
}

export async function patchStream(
  id: string,
  patch: Partial<LiveStream>,
): Promise<LiveStream | undefined> {
  const current = await getStreamById(id);
  if (!current) return undefined;
  const next = { ...current, ...patch };
  return upsertStream(next);
}

export async function endLiveStream(id: string): Promise<LiveStream | undefined> {
  const current = await getStreamById(id);
  if (!current) return undefined;
  if (current.status === "ended" || current.status === "replay") {
    return current;
  }

  const auction =
    current.auction &&
    (current.auction.status === "open" || current.auction.status === "closing")
      ? {
          ...current.auction,
          status:
            current.auction.bidderCount > 0
              ? ("sold" as const)
              : ("unsold" as const),
        }
      : current.auction;

  return upsertStream({
    ...current,
    status: "ended",
    endedAt: new Date().toISOString(),
    auction,
    replayAvailable: current.replayAvailable || Boolean(current.recordingUrl),
  });
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

export async function createLiveStream(
  input: CreateStreamInput,
): Promise<LiveStream> {
  const seller = input.sellerId
    ? { id: input.sellerId }
    : await ensureDefaultSeller();

  const id = `stream-${Date.now().toString(36)}`;
  const channelName = `hubsom_${id.replace(/[^a-z0-9]/gi, "_").toLowerCase()}`;

  const productIds: string[] = [];
  for (const pid of input.productIds) {
    if (await getProduct(pid)) productIds.push(pid);
  }

  const categories = Array.from(
    new Set(
      (
        await Promise.all(
          productIds.map(async (pid) => (await getProduct(pid))?.category),
        )
      ).filter(Boolean) as ProductCategory[],
    ),
  );

  const hosts: StreamHost[] = [
    {
      id: "host-you",
      name: "You",
      role: "host",
      avatar: "/brand/hubsom-logo.png",
    },
  ];

  if (input.multiHost) {
    hosts.push(
      {
        id: "guest-slot",
        name: "Guest slot open",
        role: "guest",
        avatar: "/brand/hubsom-logo.png",
      },
      {
        id: "mod-slot",
        name: "Moderator",
        role: "moderator",
        avatar: "/brand/hubsom-logo.png",
      },
    );
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
          endsAt: new Date(Date.now() + 1000 * 60 * 30).toISOString(),
          bidderCount: 0,
          status: "open" as const,
        }
      : undefined;

  const firstProduct = productIds[0]
    ? await getProduct(productIds[0])
    : undefined;

  const stream: LiveStream = {
    id,
    title: input.title.trim() || "Hubsom Live Show",
    description:
      input.description?.trim() ||
      "Live commerce on Hubsom — pin, bid, and one-tap checkout.",
    sellerId: seller.id,
    status: "live",
    channelName,
    cover: firstProduct?.images[0] ?? "/brand/hubsom-logo.png",
    viewerCount: 1,
    peakViewers: 1,
    startedAt: new Date().toISOString(),
    productIds,
    pinnedProductId:
      input.pinnedProductId ??
      auctionProductId ??
      productIds[0],
    hosts,
    auction,
    categories,
    latencyMs: 0,
    isMultiHost: Boolean(input.multiHost),
    replayAvailable: Boolean(input.enableRecording),
  };

  return upsertStream(stream);
}

export async function findStreamByAuctionId(auctionId: string) {
  const streams = await listAllStreams();
  return streams.find((s) => s.auction?.id === auctionId);
}

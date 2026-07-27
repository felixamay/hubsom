import { promises as fs } from "fs";
import path from "path";
import type { LiveStream, ProductCategory, StreamHost } from "@/types";
import { STREAMS } from "@/lib/data/streams";
import { getProduct } from "@/lib/data/products";

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
  const byId = new Map<string, LiveStream>();
  for (const s of STREAMS) byId.set(s.id, s);
  for (const s of Object.values(store)) byId.set(s.id, s);
  return Array.from(byId.values()).sort((a, b) => {
    const rank = (s: LiveStream) =>
      s.status === "live" ? 0 : s.status === "scheduled" ? 1 : 2;
    return rank(a) - rank(b);
  });
}

export async function getStreamById(
  id: string,
): Promise<LiveStream | undefined> {
  const store = await ensureStore();
  if (store[id]) return store[id];
  return STREAMS.find((s) => s.id === id);
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
    hosts.push(
      {
        id: "guest-slot",
        name: "Guest slot open",
        role: "guest",
        avatar:
          "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=200&q=80",
      },
      {
        id: "mod-slot",
        name: "Moderator",
        role: "moderator",
        avatar:
          "https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80",
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

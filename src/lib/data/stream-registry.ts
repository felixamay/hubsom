import { promises as fs } from "fs";
import path from "path";
import type { LiveAuction, LiveStream, ProductCategory, StreamHost } from "@/types";
import { getProduct } from "@/lib/data/products";
import { ensureDefaultSeller } from "@/lib/data/sellers";
import { withFileLock } from "@/lib/data/persist";
import { decideAuctionBid } from "@/lib/live/auction-bid";

const DATA_DIR = path.join(process.cwd(), ".data");
const STORE_FILE = path.join(DATA_DIR, "live-streams.json");
const LOCK_KEY = "live-streams.json";

type StoreShape = Record<string, LiveStream>;

async function ensureStore(): Promise<StoreShape> {
  try {
    await fs.mkdir(DATA_DIR, { recursive: true });
    const raw = await fs.readFile(STORE_FILE, "utf8");
    return JSON.parse(raw) as StoreShape;
  } catch {
    const empty: StoreShape = {};
    await writeStore(empty);
    return empty;
  }
}

async function writeStore(store: StoreShape) {
  await fs.mkdir(DATA_DIR, { recursive: true });
  const tmp = `${STORE_FILE}.${process.pid}.${Date.now()}.tmp`;
  await fs.writeFile(tmp, JSON.stringify(store, null, 2), "utf8");
  await fs.rename(tmp, STORE_FILE);
}

async function mutateStore<T>(
  fn: (store: StoreShape) => T | Promise<T>,
): Promise<T> {
  return withFileLock(LOCK_KEY, async () => {
    const store = await ensureStore();
    const result = await fn(store);
    await writeStore(store);
    return result;
  });
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
  return mutateStore((store) => {
    store[stream.id] = stream;
    return stream;
  });
}

export async function patchStream(
  id: string,
  patch: Partial<LiveStream>,
): Promise<LiveStream | undefined> {
  return mutateStore((store) => {
    const current = store[id];
    if (!current) return undefined;
    const next = { ...current, ...patch };
    store[id] = next;
    return next;
  });
}

export async function endLiveStream(id: string): Promise<LiveStream | undefined> {
  return mutateStore((store) => {
    const current = store[id];
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
              current.auction.bidderCount > 0 ||
              Boolean(current.auction.highestBidderId)
                ? ("sold" as const)
                : ("unsold" as const),
          }
        : current.auction;

    const next: LiveStream = {
      ...current,
      status: "ended",
      endedAt: new Date().toISOString(),
      auction,
      replayAvailable: current.replayAvailable || Boolean(current.recordingUrl),
    };
    store[id] = next;
    return next;
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

export async function findStreamByChannelName(channelName: string) {
  const streams = await listAllStreams();
  return streams.find((s) => s.channelName === channelName);
}

export type PlaceAuctionBidInput = {
  auctionId: string;
  amountGhs?: number;
  bidderName: string;
  bidderUserId: string;
};

export type PlaceAuctionBidResult =
  | { ok: true; stream: LiveStream; auction: LiveAuction }
  | {
      ok: false;
      status: number;
      error: string;
      auction?: LiveAuction;
      minNextGhs?: number;
      currentBidGhs?: number;
    };

export async function placeAuctionBid(
  input: PlaceAuctionBidInput,
): Promise<PlaceAuctionBidResult> {
  return withFileLock(LOCK_KEY, async () => {
    const store = await ensureStore();
    const stream = Object.values(store).find(
      (s) => s.auction?.id === input.auctionId,
    );
    if (!stream?.auction) {
      return { ok: false, status: 404, error: "Auction not found" };
    }

    const decision = decideAuctionBid({
      auction: stream.auction,
      amountGhs: input.amountGhs,
      bidderName: input.bidderName,
      bidderUserId: input.bidderUserId,
    });

    if (decision.kind === "closed") {
      return { ok: false, status: 400, error: decision.error };
    }

    if (decision.kind === "too_low") {
      return {
        ok: false,
        status: 400,
        error: decision.error,
        minNextGhs: decision.minNextGhs,
        currentBidGhs: decision.currentBidGhs,
        auction: stream.auction,
      };
    }

    const next: LiveStream = { ...stream, auction: decision.auction };
    store[stream.id] = next;
    await writeStore(store);

    if (decision.kind === "expired") {
      return {
        ok: false,
        status: 400,
        error: decision.error,
        auction: decision.auction,
      };
    }

    return { ok: true, stream: next, auction: decision.auction };
  });
}

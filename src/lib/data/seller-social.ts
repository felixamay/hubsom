import { readJsonFile, writeJsonFile } from "@/lib/data/persist";

const FILE = "seller-social.json";

export type SellerReview = {
  id: string;
  sellerId: string;
  userId: string;
  userName: string;
  rating: number;
  text: string;
  createdAt: string;
};

export type SellerTip = {
  id: string;
  sellerId: string;
  userId: string;
  userName: string;
  amountGhs: number;
  streamId?: string;
  createdAt: string;
};

export type SellerReport = {
  id: string;
  sellerId: string;
  userId: string;
  reason: string;
  details?: string;
  streamId?: string;
  createdAt: string;
};

export type SellerMessage = {
  id: string;
  sellerId: string;
  fromUserId: string;
  fromUserName: string;
  text: string;
  createdAt: string;
};

type Store = {
  reviews: SellerReview[];
  tips: SellerTip[];
  reports: SellerReport[];
  blocks: Record<string, string[]>; // userId -> sellerIds blocked
  messages: SellerMessage[];
};

async function load(): Promise<Store> {
  return readJsonFile<Store>(FILE, {
    reviews: [],
    tips: [],
    reports: [],
    blocks: {},
    messages: [],
  });
}

async function save(store: Store) {
  await writeJsonFile(FILE, store);
}

export async function isSellerBlocked(
  userId: string,
  sellerId: string,
): Promise<boolean> {
  const store = await load();
  return Boolean(store.blocks[userId]?.includes(sellerId));
}

export async function blockSeller(userId: string, sellerId: string) {
  const store = await load();
  const list = new Set(store.blocks[userId] ?? []);
  list.add(sellerId);
  store.blocks[userId] = Array.from(list);
  await save(store);
  return { blocked: true };
}

export async function unblockSeller(userId: string, sellerId: string) {
  const store = await load();
  store.blocks[userId] = (store.blocks[userId] ?? []).filter((id) => id !== sellerId);
  await save(store);
  return { blocked: false };
}

export async function reportSeller(input: {
  sellerId: string;
  userId: string;
  reason: string;
  details?: string;
  streamId?: string;
}) {
  const store = await load();
  const report: SellerReport = {
    id: `report-${Date.now().toString(36)}`,
    sellerId: input.sellerId,
    userId: input.userId,
    reason: input.reason.trim() || "Other",
    details: input.details?.trim(),
    streamId: input.streamId,
    createdAt: new Date().toISOString(),
  };
  store.reports.unshift(report);
  await save(store);
  return report;
}

export async function tipSeller(input: {
  sellerId: string;
  userId: string;
  userName: string;
  amountGhs: number;
  streamId?: string;
}) {
  if (!Number.isFinite(input.amountGhs) || input.amountGhs <= 0) {
    throw new Error("Enter a tip amount greater than 0");
  }
  const store = await load();
  const tip: SellerTip = {
    id: `tip-${Date.now().toString(36)}`,
    sellerId: input.sellerId,
    userId: input.userId,
    userName: input.userName,
    amountGhs: Math.round(input.amountGhs * 100) / 100,
    streamId: input.streamId,
    createdAt: new Date().toISOString(),
  };
  store.tips.unshift(tip);
  await save(store);
  return tip;
}

export async function reviewSeller(input: {
  sellerId: string;
  userId: string;
  userName: string;
  rating: number;
  text: string;
}) {
  const rating = Math.min(5, Math.max(1, Math.round(input.rating)));
  const text = input.text.trim();
  if (!text) throw new Error("Write a short review");

  const store = await load();
  const existingIdx = store.reviews.findIndex(
    (r) => r.sellerId === input.sellerId && r.userId === input.userId,
  );
  const review: SellerReview = {
    id:
      existingIdx >= 0
        ? store.reviews[existingIdx].id
        : `review-${Date.now().toString(36)}`,
    sellerId: input.sellerId,
    userId: input.userId,
    userName: input.userName,
    rating,
    text,
    createdAt: new Date().toISOString(),
  };
  if (existingIdx >= 0) store.reviews[existingIdx] = review;
  else store.reviews.unshift(review);
  await save(store);
  return review;
}

export async function messageSeller(input: {
  sellerId: string;
  fromUserId: string;
  fromUserName: string;
  text: string;
}) {
  const text = input.text.trim();
  if (!text) throw new Error("Message can’t be empty");
  const store = await load();
  const message: SellerMessage = {
    id: `msg-${Date.now().toString(36)}`,
    sellerId: input.sellerId,
    fromUserId: input.fromUserId,
    fromUserName: input.fromUserName,
    text,
    createdAt: new Date().toISOString(),
  };
  store.messages.unshift(message);
  await save(store);
  return message;
}

export async function listReviewsForSeller(sellerId: string) {
  const store = await load();
  return store.reviews.filter((r) => r.sellerId === sellerId);
}

import { readJsonFile, writeJsonFile } from "@/lib/data/persist";
import { updateProductRating } from "@/lib/data/products";

const FILE = "product-reviews.json";

export type ProductReview = {
  id: string;
  productId: string;
  userId: string;
  userName: string;
  rating: number;
  text: string;
  createdAt: string;
};

type Store = { reviews: ProductReview[] };

async function load(): Promise<Store> {
  return readJsonFile<Store>(FILE, { reviews: [] });
}

async function save(store: Store) {
  await writeJsonFile(FILE, store);
}

async function syncProductAggregates(productId: string) {
  const reviews = await listReviewsForProduct(productId);
  if (!reviews.length) {
    await updateProductRating(productId, 0, 0);
    return;
  }
  const avg =
    reviews.reduce((sum, r) => sum + r.rating, 0) / Math.max(1, reviews.length);
  await updateProductRating(
    productId,
    Math.round(avg * 10) / 10,
    reviews.length,
  );
}

export async function listReviewsForProduct(
  productId: string,
): Promise<ProductReview[]> {
  const store = await load();
  return store.reviews.filter((r) => r.productId === productId);
}

export async function getUserProductReview(
  productId: string,
  userId: string,
): Promise<ProductReview | undefined> {
  const store = await load();
  return store.reviews.find(
    (r) => r.productId === productId && r.userId === userId,
  );
}

export async function reviewProduct(input: {
  productId: string;
  userId: string;
  userName: string;
  rating: number;
  text: string;
}): Promise<ProductReview> {
  const rating = Math.min(5, Math.max(1, Math.round(input.rating)));
  const text = input.text.trim();
  if (!text) throw new Error("Write a short review");

  const store = await load();
  const existingIdx = store.reviews.findIndex(
    (r) => r.productId === input.productId && r.userId === input.userId,
  );
  const review: ProductReview = {
    id:
      existingIdx >= 0
        ? store.reviews[existingIdx].id
        : `prev-${Date.now().toString(36)}`,
    productId: input.productId,
    userId: input.userId,
    userName: input.userName,
    rating,
    text,
    createdAt: new Date().toISOString(),
  };
  if (existingIdx >= 0) store.reviews[existingIdx] = review;
  else store.reviews.unshift(review);
  await save(store);
  await syncProductAggregates(input.productId);
  return review;
}

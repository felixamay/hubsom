import { ALL_FULFILLMENT_MODES } from "@/lib/categories";
import { mutateJsonFile, readJsonFile, slugify } from "@/lib/data/persist";
import { getEffectivePrice } from "@/lib/pricing";
import type { Product, ProductBundle, ProductCategory } from "@/types";

export { getEffectivePrice };

const FILE = "products.json";
const EMPTY: Store = { products: [], bundles: [] };
type Store = { products: Product[]; bundles: ProductBundle[] };

async function load(): Promise<Store> {
  return readJsonFile<Store>(FILE, EMPTY);
}

async function mutateStore(
  mutate: (store: Store) => void | Store | Promise<void | Store>,
): Promise<Store> {
  return mutateJsonFile(FILE, EMPTY, mutate);
}

export async function listProducts(): Promise<Product[]> {
  const store = await load();
  return store.products;
}

export async function getProduct(id: string): Promise<Product | undefined> {
  const store = await load();
  return store.products.find((p) => p.id === id);
}

export async function getProductBySlug(slug: string): Promise<Product | undefined> {
  const store = await load();
  return store.products.find((p) => p.slug === slug);
}

export async function getProductsBySeller(sellerId: string): Promise<Product[]> {
  const store = await load();
  return store.products.filter((p) => p.sellerId === sellerId);
}

export async function getProductsByCategory(category: string): Promise<Product[]> {
  const store = await load();
  return store.products.filter((p) => p.category === category);
}

export async function getFlashSaleProducts(): Promise<Product[]> {
  const store = await load();
  return store.products.filter((p) => p.flashSale);
}

export async function listBundles(): Promise<ProductBundle[]> {
  const store = await load();
  return store.bundles;
}

export interface CreateProductInput {
  name: string;
  description?: string;
  category: ProductCategory;
  priceGhs: number;
  compareAtGhs?: number;
  stock: number;
  sellerId: string;
  images?: string[];
  tags?: string[];
  flashSale?: Product["flashSale"];
}

export async function createProduct(input: CreateProductInput): Promise<Product> {
  const images = (input.images ?? []).filter(Boolean);
  if (images.length < 3) {
    throw new Error("Upload at least 3 product images before saving");
  }

  let created: Product | undefined;
  await mutateStore((store) => {
    const baseSlug = slugify(input.name) || "product";
    let slug = baseSlug;
    let n = 1;
    while (store.products.some((p) => p.slug === slug)) {
      slug = `${baseSlug}-${n++}`;
    }

    created = {
      id: `prod-${Date.now().toString(36)}`,
      slug,
      name: input.name.trim(),
      description: input.description?.trim() || "",
      category: input.category,
      priceGhs: Math.max(0, Number(input.priceGhs) || 0),
      compareAtGhs: input.compareAtGhs,
      currency: "GHS",
      images,
      sellerId: input.sellerId,
      stock: Math.max(0, Math.floor(Number(input.stock) || 0)),
      rating: 0,
      reviewCount: 0,
      tags: input.tags ?? [],
      flashSale: input.flashSale,
      supports: [...ALL_FULFILLMENT_MODES],
    };
    store.products.unshift(created);
  });
  return created!;
}

export async function updateProductStock(
  productId: string,
  stock: number,
): Promise<Product | undefined> {
  let updated: Product | undefined;
  await mutateStore((store) => {
    const idx = store.products.findIndex((p) => p.id === productId);
    if (idx < 0) return;
    store.products[idx] = {
      ...store.products[idx],
      stock: Math.max(0, Math.floor(stock)),
    };
    updated = store.products[idx];
  });
  return updated;
}

export async function adjustProductStock(
  productId: string,
  delta: number,
): Promise<Product | undefined> {
  if (!Number.isFinite(delta)) return undefined;
  let updated: Product | undefined;
  await mutateStore((store) => {
    const idx = store.products.findIndex((p) => p.id === productId);
    if (idx < 0) return;
    store.products[idx] = {
      ...store.products[idx],
      stock: Math.max(0, Math.floor(store.products[idx].stock + delta)),
    };
    updated = store.products[idx];
  });
  return updated;
}

/**
 * Apply every stock delta in one locked write, or throw and leave the
 * catalog unchanged. Refuses to take stock below zero so concurrent
 * checkouts cannot oversell a last unit.
 */
export async function applyStockDeltas(
  deltas: Array<{ productId: string; delta: number }>,
): Promise<Product[]> {
  if (!deltas.length) return [];
  const applied: Product[] = [];
  await mutateStore((store) => {
    for (const { productId, delta } of deltas) {
      if (!Number.isFinite(delta) || !Number.isInteger(delta)) {
        throw new Error("Invalid stock adjustment");
      }
      const idx = store.products.findIndex((p) => p.id === productId);
      if (idx < 0) {
        throw new Error(`Unknown product ${productId}`);
      }
      const next = store.products[idx].stock + delta;
      if (next < 0) {
        throw new Error(`Insufficient stock for ${store.products[idx].name}`);
      }
      store.products[idx] = {
        ...store.products[idx],
        stock: next,
      };
      applied.push(store.products[idx]);
    }
  });
  return applied;
}

export async function updateProductRating(
  productId: string,
  rating: number,
  reviewCount: number,
): Promise<Product | undefined> {
  let updated: Product | undefined;
  await mutateStore((store) => {
    const idx = store.products.findIndex((p) => p.id === productId);
    if (idx < 0) return;
    store.products[idx] = {
      ...store.products[idx],
      rating: Math.max(0, Math.min(5, rating)),
      reviewCount: Math.max(0, Math.floor(reviewCount)),
    };
    updated = store.products[idx];
  });
  return updated;
}

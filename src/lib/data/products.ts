import { ALL_FULFILLMENT_MODES } from "@/lib/categories";
import { readJsonFile, slugify, writeJsonFile } from "@/lib/data/persist";
import { getEffectivePrice } from "@/lib/pricing";
import type { Product, ProductBundle, ProductCategory } from "@/types";

export { getEffectivePrice };

const FILE = "products.json";
type Store = { products: Product[]; bundles: ProductBundle[] };

async function load(): Promise<Store> {
  return readJsonFile<Store>(FILE, { products: [], bundles: [] });
}

async function save(store: Store) {
  await writeJsonFile(FILE, store);
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
  const store = await load();
  const baseSlug = slugify(input.name) || "product";
  let slug = baseSlug;
  let n = 1;
  while (store.products.some((p) => p.slug === slug)) {
    slug = `${baseSlug}-${n++}`;
  }

  const product: Product = {
    id: `prod-${Date.now().toString(36)}`,
    slug,
    name: input.name.trim(),
    description: input.description?.trim() || "",
    category: input.category,
    priceGhs: Math.max(0, Number(input.priceGhs) || 0),
    compareAtGhs: input.compareAtGhs,
    currency: "GHS",
    images:
      input.images?.filter(Boolean).length
        ? input.images.filter(Boolean)
        : ["/brand/hubsom-logo.png"],
    sellerId: input.sellerId,
    stock: Math.max(0, Math.floor(Number(input.stock) || 0)),
    rating: 0,
    reviewCount: 0,
    tags: input.tags ?? [],
    flashSale: input.flashSale,
    supports: [...ALL_FULFILLMENT_MODES],
  };

  store.products.unshift(product);
  await save(store);
  return product;
}

export async function updateProductStock(
  productId: string,
  stock: number,
): Promise<Product | undefined> {
  const store = await load();
  const idx = store.products.findIndex((p) => p.id === productId);
  if (idx < 0) return undefined;
  store.products[idx] = {
    ...store.products[idx],
    stock: Math.max(0, Math.floor(stock)),
  };
  await save(store);
  return store.products[idx];
}

export async function adjustProductStock(
  productId: string,
  delta: number,
): Promise<Product | undefined> {
  const product = await getProduct(productId);
  if (!product) return undefined;
  return updateProductStock(productId, product.stock + delta);
}

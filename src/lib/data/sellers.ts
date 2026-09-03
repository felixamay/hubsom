import { readJsonFile, slugify, writeJsonFile } from "@/lib/data/persist";
import type { ProductCategory, Seller } from "@/types";

const FILE = "sellers.json";
type Store = { sellers: Seller[] };

async function load(): Promise<Store> {
  return readJsonFile<Store>(FILE, { sellers: [] });
}

async function save(store: Store) {
  await writeJsonFile(FILE, store);
}

export async function listSellers(): Promise<Seller[]> {
  const store = await load();
  return store.sellers;
}

export async function getSeller(id: string): Promise<Seller | undefined> {
  const store = await load();
  return store.sellers.find((s) => s.id === id);
}

export async function getSellerBySlug(slug: string): Promise<Seller | undefined> {
  const store = await load();
  return store.sellers.find((s) => s.slug === slug);
}

export interface CreateSellerInput {
  name: string;
  city?: string;
  region?: string;
  bio?: string;
  avatar?: string;
  cover?: string;
  categories?: ProductCategory[];
  ownerUserId?: string;
}

/** Ensures a default seller exists for local/dev host flows. */
export async function ensureDefaultSeller(): Promise<Seller> {
  const store = await load();
  const existing = store.sellers.find((s) => s.id === "seller-you");
  if (existing) return existing;

  const seller: Seller = {
    id: "seller-you",
    slug: "my-hubsom-store",
    name: "My Hubsom Store",
    city: "Accra",
    region: "Greater Accra",
    bio: "Your Hubsom storefront — list products, go live, and sell across categories.",
    avatar: "/brand/hubsom-logo.png",
    cover: "/brand/hubsom-logo.png",
    rating: 0,
    followers: 0,
    verified: false,
    categories: [],
  };
  store.sellers.unshift(seller);
  await save(store);
  return seller;
}

/** Creates or returns the storefront owned by a Hubsom user. */
export async function ensureSellerForUser(input: {
  userId: string;
  name: string;
  city?: string;
  region?: string;
  bio?: string;
  avatar?: string;
}): Promise<Seller> {
  const store = await load();
  const existing = store.sellers.find((s) => s.ownerUserId === input.userId);
  if (existing) {
    const idx = store.sellers.findIndex((s) => s.id === existing.id);
    // Keep customized storefront branding — only fill missing location/bio defaults.
    store.sellers[idx] = {
      ...existing,
      city: existing.city || input.city || "Accra",
      region: existing.region || input.region || "Greater Accra",
      bio: existing.bio || input.bio || existing.bio,
    };
    await save(store);
    return store.sellers[idx];
  }

  return createSeller({
    name: `${input.name}'s Store`,
    city: input.city,
    region: input.region,
    bio: input.bio,
    avatar: input.avatar,
    ownerUserId: input.userId,
  });
}

export async function getSellerByOwnerUserId(
  userId: string,
): Promise<Seller | undefined> {
  const store = await load();
  return store.sellers.find((s) => s.ownerUserId === userId);
}

export async function createSeller(input: CreateSellerInput): Promise<Seller> {
  const store = await load();
  const baseSlug = slugify(input.name) || "store";
  let slug = baseSlug;
  let n = 1;
  while (store.sellers.some((s) => s.slug === slug)) {
    slug = `${baseSlug}-${n++}`;
  }

  const seller: Seller = {
    id: `seller-${Date.now().toString(36)}`,
    slug,
    name: input.name.trim(),
    city: input.city?.trim() || "Accra",
    region: input.region?.trim() || "Greater Accra",
    bio: input.bio?.trim() || "",
    avatar: input.avatar || "/brand/hubsom-logo.png",
    cover: input.cover || "/brand/hubsom-logo.png",
    rating: 0,
    followers: 0,
    verified: false,
    categories: input.categories ?? [],
    ownerUserId: input.ownerUserId,
  };

  store.sellers.unshift(seller);
  await save(store);
  return seller;
}

export async function updateSeller(
  id: string,
  patch: Partial<
    Pick<
      Seller,
      | "name"
      | "slug"
      | "city"
      | "region"
      | "bio"
      | "avatar"
      | "cover"
      | "categories"
      | "followers"
      | "rating"
      | "verified"
      | "ownerUserId"
    >
  >,
): Promise<Seller | undefined> {
  const store = await load();
  const idx = store.sellers.findIndex((s) => s.id === id);
  if (idx < 0) return undefined;

  const current = store.sellers[idx];
  let slug = current.slug;
  if (patch.name && patch.name.trim() && patch.name.trim() !== current.name) {
    const baseSlug = slugify(patch.name) || current.slug;
    slug = baseSlug;
    let n = 1;
    while (
      store.sellers.some((s, i) => i !== idx && s.slug === slug)
    ) {
      slug = `${baseSlug}-${n++}`;
    }
  }

  store.sellers[idx] = {
    ...current,
    ...patch,
    id,
    slug: patch.slug ?? slug,
    name: patch.name?.trim() || current.name,
    city: patch.city?.trim() || current.city,
    region: patch.region?.trim() || current.region,
    bio: patch.bio !== undefined ? patch.bio.trim() : current.bio,
    avatar: patch.avatar || current.avatar,
    cover: patch.cover || current.cover,
  };
  await save(store);
  return store.sellers[idx];
}

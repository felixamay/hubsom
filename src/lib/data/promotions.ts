import { readJsonFile, writeJsonFile } from "@/lib/data/persist";
import type { ProductCategory } from "@/types";
import type {
  AdminPromotionInput,
  PromoPlacement,
  PromoTone,
  Promotion,
} from "@/types/promotions";

const FILE = "promotions.json";
type Store = { promotions: Promotion[] };

const SEED: Promotion[] = [
  {
    id: "promo-live-weekend",
    title: "Weekend live drops",
    subtitle: "Sellers go live with limited stock — tap in before it sells out.",
    ctaLabel: "Watch live",
    href: "/live",
    tone: "live",
    placements: ["landing", "marketplace"],
    active: true,
    source: "seed",
    sortOrder: 10,
  },
  {
    id: "promo-flash-hub",
    title: "Flash sale lane",
    subtitle: "Timed discounts across categories — Buy Now in GHS.",
    ctaLabel: "Shop flash",
    href: "/flash-sales",
    tone: "gold",
    placements: ["landing", "marketplace", "category"],
    active: true,
    source: "seed",
    sortOrder: 20,
  },
  {
    id: "promo-fashion-edit",
    title: "Fashion edit",
    subtitle: "New Ankara & streetwear picks from Hubsom stores.",
    ctaLabel: "Browse fashion",
    href: "/categories/fashion",
    tone: "cyan",
    placements: ["landing", "category", "product"],
    categorySlugs: ["fashion"],
    active: true,
    source: "seed",
    sortOrder: 30,
  },
  {
    id: "promo-phones",
    title: "Phones & accessories",
    subtitle: "Deals on gadgets from verified sellers.",
    ctaLabel: "Shop phones",
    href: "/categories/phones-accessories",
    tone: "forest",
    placements: ["category", "marketplace"],
    categorySlugs: ["phones-accessories"],
    active: true,
    source: "seed",
    sortOrder: 40,
  },
];

function normalizePlacement(p: string): PromoPlacement | null {
  if (p === "home") return "landing";
  if (
    p === "landing" ||
    p === "marketplace" ||
    p === "category" ||
    p === "product"
  ) {
    return p;
  }
  return null;
}

function normalizePromotion(raw: Promotion): Promotion {
  const placements = Array.from(
    new Set(
      (raw.placements ?? [])
        .map((p) => normalizePlacement(String(p)))
        .filter((p): p is PromoPlacement => Boolean(p)),
    ),
  );
  const categorySlugs = Array.from(
    new Set(
      [
        ...(raw.categorySlugs ?? []),
        ...(raw.categorySlug ? [raw.categorySlug] : []),
      ].map((s) => String(s).trim())
        .filter(Boolean),
    ),
  ) as ProductCategory[];

  return {
    ...raw,
    placements,
    categorySlugs: categorySlugs.length ? categorySlugs : undefined,
    productIds: Array.from(
      new Set((raw.productIds ?? []).map((id) => String(id).trim()).filter(Boolean)),
    ),
    tone: (["forest", "gold", "cyan", "live"].includes(raw.tone)
      ? raw.tone
      : "forest") as PromoTone,
    sortOrder: typeof raw.sortOrder === "number" ? raw.sortOrder : 100,
    source: raw.source === "admin" ? "admin" : raw.source === "seed" ? "seed" : raw.source,
  };
}

async function load(): Promise<Store> {
  const store = await readJsonFile<Store>(FILE, { promotions: [] });
  if (!store.promotions.length) {
    store.promotions = SEED;
    await writeJsonFile(FILE, store);
  }
  store.promotions = store.promotions.map(normalizePromotion);
  return store;
}

async function save(store: Store) {
  await writeJsonFile(FILE, store);
}

function isCurrentlyActive(promo: Promotion, now = Date.now()) {
  if (!promo.active) return false;
  if (promo.startsAt && new Date(promo.startsAt).getTime() > now) return false;
  if (promo.endsAt && new Date(promo.endsAt).getTime() < now) return false;
  return true;
}

function matchesPlacement(promo: Promotion, placement: PromoPlacement) {
  return promo.placements.includes(placement);
}

function matchesCategory(promo: Promotion, categorySlug?: string) {
  if (!categorySlug) return true;
  const slugs = promo.categorySlugs ?? [];
  if (!slugs.length) return true; // unscoped = all categories
  return slugs.includes(categorySlug as ProductCategory);
}

function matchesProduct(promo: Promotion, productId?: string) {
  if (!productId) return true;
  const ids = promo.productIds ?? [];
  if (!ids.length) return true; // unscoped = all products
  return ids.includes(productId);
}

export async function listPromotions(input?: {
  placement?: PromoPlacement | "home";
  categorySlug?: ProductCategory | string;
  productId?: string;
  limit?: number;
  includeInactive?: boolean;
}): Promise<Promotion[]> {
  const store = await load();
  const placement = input?.placement
    ? normalizePlacement(input.placement)
    : null;

  let list = store.promotions
    .map(normalizePromotion)
    .filter((p) => (input?.includeInactive ? true : isCurrentlyActive(p)));

  if (placement) {
    list = list.filter((p) => matchesPlacement(p, placement));
  }

  if (placement === "category" || input?.categorySlug) {
    list = list.filter((p) => matchesCategory(p, input?.categorySlug));
  }

  if (placement === "product" || input?.productId) {
    list = list.filter((p) => matchesProduct(p, input?.productId));
    // Product pages can also show category-scoped product promos
    if (input?.categorySlug) {
      list = list.filter((p) => matchesCategory(p, input.categorySlug));
    }
  }

  list.sort(
    (a, b) =>
      (a.sortOrder ?? 100) - (b.sortOrder ?? 100) ||
      String(a.title).localeCompare(String(b.title)),
  );

  if (typeof input?.limit === "number") {
    list = list.slice(0, Math.max(0, input.limit));
  }

  return list;
}

export async function listAllPromotionsAdmin(): Promise<Promotion[]> {
  const store = await load();
  return store.promotions
    .map(normalizePromotion)
    .sort(
      (a, b) =>
        (a.sortOrder ?? 100) - (b.sortOrder ?? 100) ||
        String(a.updatedAt ?? "").localeCompare(String(b.updatedAt ?? "")),
    );
}

export async function getPromotion(
  id: string,
): Promise<Promotion | undefined> {
  const store = await load();
  return store.promotions.map(normalizePromotion).find((p) => p.id === id);
}

function validateInput(input: AdminPromotionInput) {
  const title = String(input.title ?? "").trim();
  const href = String(input.href ?? "").trim();
  if (!title) throw new Error("title is required");
  if (!href) throw new Error("href is required");

  const placements = Array.from(
    new Set(
      (input.placements ?? [])
        .map((p) => normalizePlacement(String(p)))
        .filter((p): p is PromoPlacement => Boolean(p)),
    ),
  );
  if (!placements.length) {
    throw new Error(
      "Select at least one placement: landing, marketplace, category, or product",
    );
  }

  return {
    title,
    href,
    subtitle: String(input.subtitle ?? "").trim(),
    ctaLabel: String(input.ctaLabel ?? "Shop now").trim() || "Shop now",
    tone: (["forest", "gold", "cyan", "live"].includes(String(input.tone))
      ? input.tone
      : "forest") as PromoTone,
    placements,
    categorySlugs: Array.from(
      new Set(
        (input.categorySlugs ?? [])
          .map((s) => String(s).trim())
          .filter(Boolean),
      ),
    ) as ProductCategory[],
    productIds: Array.from(
      new Set(
        (input.productIds ?? []).map((s) => String(s).trim()).filter(Boolean),
      ),
    ),
    imageUrl: String(input.imageUrl ?? "").trim() || undefined,
    sortOrder:
      typeof input.sortOrder === "number" && Number.isFinite(input.sortOrder)
        ? input.sortOrder
        : 100,
    active: input.active !== false,
    startsAt: input.startsAt ? String(input.startsAt) : undefined,
    endsAt: input.endsAt ? String(input.endsAt) : undefined,
  };
}

export async function upsertPromotionFromAdmin(
  input: AdminPromotionInput,
): Promise<Promotion> {
  const parsed = validateInput(input);
  const store = await load();
  const now = new Date().toISOString();
  const id =
    String(input.id ?? "").trim() || `promo_${Date.now().toString(36)}`;
  const existingIdx = store.promotions.findIndex((p) => p.id === id);

  const next: Promotion = {
    id,
    ...parsed,
    categorySlugs: parsed.categorySlugs.length
      ? parsed.categorySlugs
      : undefined,
    productIds: parsed.productIds.length ? parsed.productIds : undefined,
    source: "admin",
    createdAt:
      existingIdx >= 0
        ? store.promotions[existingIdx].createdAt ?? now
        : now,
    updatedAt: now,
  };

  if (existingIdx >= 0) store.promotions[existingIdx] = next;
  else store.promotions.unshift(next);
  await save(store);
  return normalizePromotion(next);
}

export async function deletePromotion(id: string): Promise<boolean> {
  const store = await load();
  const before = store.promotions.length;
  store.promotions = store.promotions.filter((p) => p.id !== id);
  if (store.promotions.length === before) return false;
  await save(store);
  return true;
}

export async function replaceAllPromotionsFromAdmin(
  items: AdminPromotionInput[],
): Promise<Promotion[]> {
  if (!Array.isArray(items)) throw new Error("promotions array required");
  const now = new Date().toISOString();
  const promotions = items.map((item, index) => {
    const parsed = validateInput(item);
    const id =
      String(item.id ?? "").trim() ||
      `promo_${Date.now().toString(36)}_${index}`;
    return normalizePromotion({
      id,
      ...parsed,
      categorySlugs: parsed.categorySlugs.length
        ? parsed.categorySlugs
        : undefined,
      productIds: parsed.productIds.length ? parsed.productIds : undefined,
      source: "admin",
      createdAt: now,
      updatedAt: now,
    });
  });
  await save({ promotions });
  return promotions;
}

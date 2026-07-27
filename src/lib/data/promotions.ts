import { readJsonFile, writeJsonFile } from "@/lib/data/persist";
import type { ProductCategory } from "@/types";
import type { PromoPlacement, Promotion } from "@/types/promotions";

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
    placements: ["home", "marketplace"],
    active: true,
  },
  {
    id: "promo-flash-hub",
    title: "Flash sale lane",
    subtitle: "Timed discounts across categories — Buy Now in GHS.",
    ctaLabel: "Shop flash",
    href: "/flash-sales",
    tone: "gold",
    placements: ["home", "marketplace", "category"],
    active: true,
  },
  {
    id: "promo-fashion-edit",
    title: "Fashion edit",
    subtitle: "New Ankara & streetwear picks from Hubsom stores.",
    ctaLabel: "Browse fashion",
    href: "/categories/fashion",
    tone: "cyan",
    placements: ["home", "category", "product"],
    categorySlug: "fashion",
    active: true,
  },
  {
    id: "promo-phones",
    title: "Phones & accessories",
    subtitle: "Deals on gadgets from verified sellers.",
    ctaLabel: "Shop phones",
    href: "/categories/phones-accessories",
    tone: "forest",
    placements: ["category", "marketplace"],
    categorySlug: "phones-accessories",
    active: true,
  },
  {
    id: "promo-hubers-dispatch",
    title: "Faster delivery with Hubers",
    subtitle: "Sellers consolidate orders and send rides to approved riders.",
    ctaLabel: "Learn more",
    href: "/marketplace",
    tone: "forest",
    placements: ["home", "product"],
    active: true,
  },
];

async function load(): Promise<Store> {
  const store = await readJsonFile<Store>(FILE, { promotions: [] });
  if (!store.promotions.length) {
    store.promotions = SEED;
    await writeJsonFile(FILE, store);
  }
  return store;
}

function isCurrentlyActive(promo: Promotion, now = Date.now()) {
  if (!promo.active) return false;
  if (promo.startsAt && new Date(promo.startsAt).getTime() > now) return false;
  if (promo.endsAt && new Date(promo.endsAt).getTime() < now) return false;
  return true;
}

export async function listPromotions(input?: {
  placement?: PromoPlacement;
  categorySlug?: ProductCategory | string;
  limit?: number;
}): Promise<Promotion[]> {
  const store = await load();
  let list = store.promotions.filter((p) => isCurrentlyActive(p));

  if (input?.placement) {
    list = list.filter((p) => p.placements.includes(input.placement!));
  }

  if (input?.categorySlug) {
    list = list.filter(
      (p) => !p.categorySlug || p.categorySlug === input.categorySlug,
    );
  } else if (input?.placement === "category") {
    // On generic category browse, prefer unscoped + any active category promos
    list = list.filter((p) => p.placements.includes("category"));
  }

  if (typeof input?.limit === "number") {
    list = list.slice(0, Math.max(0, input.limit));
  }

  return list;
}

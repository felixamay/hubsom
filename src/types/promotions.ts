import type { ProductCategory } from "@/types";

/** Where HubsomAdmin can place a promotion on the storefront. */
export type PromoPlacement =
  | "landing" // home / landing page
  | "marketplace"
  | "category"
  | "product";

/** @deprecated use "landing" — kept for older seed records */
export type LegacyPromoPlacement = "home";

export type PromoTone = "forest" | "gold" | "cyan" | "live";

export interface Promotion {
  id: string;
  title: string;
  subtitle: string;
  ctaLabel: string;
  href: string;
  tone: PromoTone;
  /** Surfaces selected in HubsomAdmin */
  placements: PromoPlacement[];
  /**
   * When placements includes "category":
   * empty = all category pages; otherwise only these slugs.
   */
  categorySlugs?: ProductCategory[];
  /**
   * When placements includes "product":
   * empty = all product pages; otherwise only these product ids.
   */
  productIds?: string[];
  /** Optional hero/banner image from admin */
  imageUrl?: string;
  sortOrder?: number;
  active: boolean;
  startsAt?: string;
  endsAt?: string;
  source?: "admin" | "seed";
  createdAt?: string;
  updatedAt?: string;
  /** @deprecated use categorySlugs */
  categorySlug?: ProductCategory;
}

/** Shape HubsomAdmin POSTs / PUTs */
export type AdminPromotionInput = {
  id?: string;
  title: string;
  subtitle?: string;
  ctaLabel?: string;
  href: string;
  tone?: PromoTone;
  placements: PromoPlacement[];
  categorySlugs?: string[];
  productIds?: string[];
  imageUrl?: string;
  sortOrder?: number;
  active?: boolean;
  startsAt?: string | null;
  endsAt?: string | null;
};

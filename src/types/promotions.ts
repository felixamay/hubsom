import type { ProductCategory } from "@/types";

export type PromoPlacement = "home" | "marketplace" | "category" | "product";

export interface Promotion {
  id: string;
  title: string;
  subtitle: string;
  ctaLabel: string;
  href: string;
  /** Visual accent key mapped in PromoSpace */
  tone: "forest" | "gold" | "cyan" | "live";
  placements: PromoPlacement[];
  /** When set, only show on matching category pages */
  categorySlug?: ProductCategory;
  active: boolean;
  startsAt?: string;
  endsAt?: string;
}

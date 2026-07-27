import type { ProductCategory } from "@/types";

export type CategoryTone = {
  bg: string;
  bgSoft: string;
  ink: string;
};

/** Distinct professional tones for category rectangle boxes (no purple). */
export const CATEGORY_TONES: Record<ProductCategory, CategoryTone> = {
  groceries: { bg: "#D8F3DC", bgSoft: "#EEF9F0", ink: "#1B4332" },
  electronics: { bg: "#D6EAF8", bgSoft: "#EEF6FC", ink: "#1A3A5C" },
  fashion: { bg: "#FDE2E4", bgSoft: "#FFF1F2", ink: "#7A1F2B" },
  shoes: { bg: "#FFE8D6", bgSoft: "#FFF4EB", ink: "#7C3A00" },
  "beauty-personal-care": { bg: "#FFD6E7", bgSoft: "#FFEAF3", ink: "#9D174D" },
  "health-wellness": { bg: "#D1FAE5", bgSoft: "#ECFDF5", ink: "#065F46" },
  "home-kitchen": { bg: "#FEF3C7", bgSoft: "#FFFBEB", ink: "#92400E" },
  furniture: { bg: "#E7E5E4", bgSoft: "#F5F5F4", ink: "#44403C" },
  "home-decor": { bg: "#FDE68A", bgSoft: "#FEF9C3", ink: "#854D0E" },
  appliances: { bg: "#E2E8F0", bgSoft: "#F8FAFC", ink: "#334155" },
  "phones-accessories": { bg: "#CFFAFE", bgSoft: "#ECFEFF", ink: "#155E75" },
  "computers-tablets": { bg: "#DBEAFE", bgSoft: "#EFF6FF", ink: "#1E3A8A" },
  gaming: { bg: "#FFEDD5", bgSoft: "#FFF7ED", ink: "#9A3412" },
  "cameras-photography": { bg: "#E5E7EB", bgSoft: "#F9FAFB", ink: "#111827" },
  "jewelry-watches": { bg: "#FEF9C3", bgSoft: "#FEFCE8", ink: "#854D0E" },
  "luxury-goods": { bg: "#F5E6D3", bgSoft: "#FAF3EB", ink: "#6B4423" },
  "baby-kids": { bg: "#FBCFE8", bgSoft: "#FCE7F3", ink: "#9D174D" },
  "toys-games": { bg: "#FDE68A", bgSoft: "#FEF3C7", ink: "#92400E" },
  "sports-outdoors": { bg: "#BBF7D0", bgSoft: "#DCFCE7", ink: "#14532D" },
  automotive: { bg: "#FECACA", bgSoft: "#FEE2E2", ink: "#7F1D1D" },
  "tools-hardware": { bg: "#FED7AA", bgSoft: "#FFEDD5", ink: "#9A3412" },
  "pet-supplies": { bg: "#FED7AA", bgSoft: "#FFEDD5", ink: "#9A3412" },
  books: { bg: "#FDE68A", bgSoft: "#FFFBEB", ink: "#78350F" },
  "music-instruments": { bg: "#A5F3FC", bgSoft: "#CFFAFE", ink: "#155E75" },
  "movies-entertainment": { bg: "#FECACA", bgSoft: "#FEE2E2", ink: "#991B1B" },
  "art-collectibles": { bg: "#FBCFE8", bgSoft: "#FCE7F3", ink: "#9D174D" },
  "antiques-vintage": { bg: "#E7E5E4", bgSoft: "#F5F5F4", ink: "#57534E" },
  "handmade-crafts": { bg: "#FDE68A", bgSoft: "#FEF9C3", ink: "#854D0E" },
  "office-school-supplies": { bg: "#BFDBFE", bgSoft: "#DBEAFE", ink: "#1E40AF" },
  "garden-outdoor": { bg: "#A7F3D0", bgSoft: "#D1FAE5", ink: "#065F46" },
  "industrial-business-equipment": {
    bg: "#CBD5E1",
    bgSoft: "#E2E8F0",
    ink: "#334155",
  },
  "digital-products": { bg: "#BAE6FD", bgSoft: "#E0F2FE", ink: "#075985" },
  services: { bg: "#99F6E4", bgSoft: "#CCFBF1", ink: "#115E59" },
  "real-estate": { bg: "#A5F3FC", bgSoft: "#CFFAFE", ink: "#0E7490" },
  vehicles: { bg: "#FDA4AF", bgSoft: "#FECDD3", ink: "#9F1239" },
  "tickets-events": { bg: "#FCD34D", bgSoft: "#FDE68A", ink: "#92400E" },
  "gift-cards": { bg: "#86EFAC", bgSoft: "#BBF7D0", ink: "#166534" },
  miscellaneous: { bg: "#E2E8F0", bgSoft: "#F1F5F9", ink: "#334155" },
};

export function categoryTone(slug: ProductCategory | string): CategoryTone {
  return (
    CATEGORY_TONES[slug as ProductCategory] ?? CATEGORY_TONES.miscellaneous
  );
}

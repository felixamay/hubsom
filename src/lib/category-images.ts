import type { ProductCategory } from "@/types";

/** Curated Unsplash stills for category tiles (landing rail + grids). */
export const CATEGORY_IMAGES: Record<ProductCategory, string> = {
  groceries:
    "https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=400&q=80",
  electronics:
    "https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=400&q=80",
  fashion:
    "https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=400&q=80",
  shoes:
    "https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=400&q=80",
  "beauty-personal-care":
    "https://images.unsplash.com/photo-1596462502278-27bfdc403348?auto=format&fit=crop&w=400&q=80",
  "health-wellness":
    "https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?auto=format&fit=crop&w=400&q=80",
  "home-kitchen":
    "https://images.unsplash.com/photo-1556911220-bff31c812dba?auto=format&fit=crop&w=400&q=80",
  furniture:
    "https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=400&q=80",
  "home-decor":
    "https://images.unsplash.com/photo-1513519245088-0e12902e35a6?auto=format&fit=crop&w=400&q=80",
  appliances:
    "https://images.unsplash.com/photo-1574269909862-7e1d70bb8078?auto=format&fit=crop&w=400&q=80",
  "phones-accessories":
    "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=400&q=80",
  "computers-tablets":
    "https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=400&q=80",
  gaming:
    "https://images.unsplash.com/photo-1606144042614-b2417e99c4e3?auto=format&fit=crop&w=400&q=80",
  "cameras-photography":
    "https://images.unsplash.com/photo-1516035069371-29a1b824cc32?auto=format&fit=crop&w=400&q=80",
  "jewelry-watches":
    "https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=400&q=80",
  "luxury-goods":
    "https://images.unsplash.com/photo-1548036328-c03512636b9e?auto=format&fit=crop&w=400&q=80",
  "baby-kids":
    "https://images.unsplash.com/photo-1515488042361-ee00e0ddd4e4?auto=format&fit=crop&w=400&q=80",
  "toys-games":
    "https://images.unsplash.com/photo-1558060370-d644479cb6f7?auto=format&fit=crop&w=400&q=80",
  "sports-outdoors":
    "https://images.unsplash.com/photo-1461896836934-ffe607ba6851?auto=format&fit=crop&w=400&q=80",
  automotive:
    "https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?auto=format&fit=crop&w=400&q=80",
  "tools-hardware":
    "https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=400&q=80",
  "pet-supplies":
    "https://images.unsplash.com/photo-1587300003388-59208cc962c0?auto=format&fit=crop&w=400&q=80",
  books:
    "https://images.unsplash.com/photo-1495446815901-a7297e633e8d?auto=format&fit=crop&w=400&q=80",
  "music-instruments":
    "https://images.unsplash.com/photo-1511379938547-c1f69419868d?auto=format&fit=crop&w=400&q=80",
  "movies-entertainment":
    "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=400&q=80",
  "art-collectibles":
    "https://images.unsplash.com/photo-1513364776144-60967b0f800f?auto=format&fit=crop&w=400&q=80",
  "antiques-vintage":
    "https://images.unsplash.com/photo-1464288553394-fd9130c66e9c?auto=format&fit=crop&w=400&q=80",
  "handmade-crafts":
    "https://images.unsplash.com/photo-1452860606245-08befc0ff44b?auto=format&fit=crop&w=400&q=80",
  "office-school-supplies":
    "https://images.unsplash.com/photo-1484480974693-6ca0a78fb36b?auto=format&fit=crop&w=400&q=80",
  "garden-outdoor":
    "https://images.unsplash.com/photo-1416879595882-3373a0480b5b?auto=format&fit=crop&w=400&q=80",
  "industrial-business-equipment":
    "https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?auto=format&fit=crop&w=400&q=80",
  "digital-products":
    "https://images.unsplash.com/photo-1551288049-bebda4e38f71?auto=format&fit=crop&w=400&q=80",
  services:
    "https://images.unsplash.com/photo-1521791136064-7986c2920216?auto=format&fit=crop&w=400&q=80",
  "real-estate":
    "https://images.unsplash.com/photo-1560518883-ce09059eeffa?auto=format&fit=crop&w=400&q=80",
  vehicles:
    "https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=400&q=80",
  "tickets-events":
    "https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?auto=format&fit=crop&w=400&q=80",
  "gift-cards":
    "https://images.unsplash.com/photo-1549465220-1a8b9238cd48?auto=format&fit=crop&w=400&q=80",
  miscellaneous:
    "https://images.unsplash.com/photo-1472851294608-062f824d29cc?auto=format&fit=crop&w=400&q=80",
};

export function categoryImage(slug: ProductCategory | string): string {
  return (
    CATEGORY_IMAGES[slug as ProductCategory] ?? CATEGORY_IMAGES.miscellaneous
  );
}

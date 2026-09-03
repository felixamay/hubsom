import type { CategoryMeta, ProductCategory } from "@/types";

/** Canonical Hubsom categories — used across Buy Now, live, auctions, flash, stores. */
export const CATEGORIES: CategoryMeta[] = [
  { slug: "groceries", name: "Groceries", description: "Food and everyday essentials — Buy Now, live, or auctioned." },
  { slug: "electronics", name: "Electronics", description: "Gadgets, audio, and consumer electronics." },
  { slug: "fashion", name: "Fashion", description: "Apparel and style from Accra to Kumasi." },
  { slug: "shoes", name: "Shoes", description: "Sneakers, sandals, and formal footwear." },
  { slug: "beauty-personal-care", name: "Beauty & Personal Care", description: "Skincare, makeup, and grooming." },
  { slug: "health-wellness", name: "Health & Wellness", description: "Wellness products and personal health." },
  { slug: "home-kitchen", name: "Home & Kitchen", description: "Cookware, tableware, and household essentials." },
  { slug: "furniture", name: "Furniture", description: "Home and office furniture." },
  { slug: "home-decor", name: "Home Décor", description: "Artful accents for living spaces." },
  { slug: "appliances", name: "Appliances", description: "Kitchen and home appliances." },
  { slug: "phones-accessories", name: "Phones & Accessories", description: "Smartphones, cases, and mobile gear." },
  { slug: "computers-tablets", name: "Computers & Tablets", description: "Laptops, tablets, and peripherals." },
  { slug: "gaming", name: "Gaming", description: "Consoles, games, and gaming gear." },
  { slug: "cameras-photography", name: "Cameras & Photography", description: "Cameras, lenses, and photo gear." },
  { slug: "jewelry-watches", name: "Jewelry & Watches", description: "Jewelry, beads, and timepieces." },
  { slug: "luxury-goods", name: "Luxury Goods", description: "Premium bags, watches, and exclusives." },
  { slug: "baby-kids", name: "Baby & Kids", description: "Care, gear, and essentials for little ones." },
  { slug: "toys-games", name: "Toys & Games", description: "Toys, puzzles, and play sets." },
  { slug: "sports-outdoors", name: "Sports & Outdoors", description: "Fitness gear and outdoor kit." },
  { slug: "automotive", name: "Automotive", description: "Parts, accessories, and vehicle care." },
  { slug: "tools-hardware", name: "Tools & Hardware", description: "Hand tools, power tools, and hardware." },
  { slug: "pet-supplies", name: "Pet Supplies", description: "Food, toys, and care for pets." },
  { slug: "books", name: "Books", description: "Education, fiction, and local titles." },
  { slug: "music-instruments", name: "Music & Instruments", description: "Instruments, audio, and sheet music." },
  { slug: "movies-entertainment", name: "Movies & Entertainment", description: "Films, media, and entertainment." },
  { slug: "art-collectibles", name: "Art & Collectibles", description: "Original works, prints, and rare finds." },
  { slug: "antiques-vintage", name: "Antiques & Vintage", description: "Timeless second-hand treasures." },
  { slug: "handmade-crafts", name: "Handmade & Crafts", description: "Crafted goods from local makers." },
  { slug: "office-school-supplies", name: "Office & School Supplies", description: "Stationery and workspace tools." },
  { slug: "garden-outdoor", name: "Garden & Outdoor", description: "Plants, outdoor living, and garden tools." },
  { slug: "industrial-business-equipment", name: "Industrial & Business Equipment", description: "Tools and equipment for trade." },
  { slug: "digital-products", name: "Digital Products", description: "Downloads, courses, and licenses." },
  { slug: "services", name: "Services", description: "Bookable services from trusted providers." },
  { slug: "real-estate", name: "Real Estate", description: "Listings and property opportunities." },
  { slug: "vehicles", name: "Vehicles", description: "Cars, motorbikes, and mobility." },
  { slug: "tickets-events", name: "Tickets & Events", description: "Event tickets and experiences." },
  { slug: "gift-cards", name: "Gift Cards", description: "Digital and physical gift cards." },
  { slug: "miscellaneous", name: "Miscellaneous", description: "Everything else that belongs on Hubsom." },
];

export const CATEGORY_MAP = Object.fromEntries(
  CATEGORIES.map((c) => [c.slug, c]),
) as Record<ProductCategory, CategoryMeta>;

export const ALL_FULFILLMENT_MODES = [
  "buy-now",
  "live-selling",
  "live-auction",
  "flash-sale",
  "bundle",
  "store-listing",
  "promotion",
] as const;

export function categoryName(slug: ProductCategory | string): string {
  return CATEGORY_MAP[slug as ProductCategory]?.name ?? slug;
}

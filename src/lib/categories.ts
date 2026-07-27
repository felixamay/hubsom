import type { CategoryMeta, ProductCategory } from "@/types";

/** Every category supports the same commerce surfaces — no grocery silo. */
export const CATEGORIES: CategoryMeta[] = [
  { slug: "groceries", name: "Groceries", description: "Everyday essentials sold Buy Now, live, or auctioned." },
  { slug: "fresh-produce", name: "Fresh Produce", description: "Farm-fresh fruits and vegetables across Ghana." },
  { slug: "meat-seafood", name: "Meat & Seafood", description: "Butcher cuts, smoked fish, and cold-chain delivery." },
  { slug: "bakery", name: "Bakery", description: "Bread, pastries, and same-day bakes." },
  { slug: "dairy", name: "Dairy", description: "Milk, yogurt, cheese, and chilled staples." },
  { slug: "frozen-foods", name: "Frozen Foods", description: "Frozen meals and ingredients ready for delivery." },
  { slug: "beverages", name: "Beverages", description: "Drinks, juices, and pantry coolers." },
  { slug: "snacks", name: "Snacks", description: "Local and imported snacks for every craving." },
  { slug: "pantry-staples", name: "Pantry Staples", description: "Rice, oil, spices, and household staples." },
  { slug: "fashion", name: "Fashion", description: "Apparel and style from Accra to Kumasi." },
  { slug: "shoes", name: "Shoes", description: "Sneakers, sandals, and formal footwear." },
  { slug: "beauty", name: "Beauty", description: "Skincare, makeup, and grooming." },
  { slug: "health", name: "Health", description: "Wellness products and personal care." },
  { slug: "electronics", name: "Electronics", description: "Phones, audio, and gadgets." },
  { slug: "computers", name: "Computers", description: "Laptops, accessories, and peripherals." },
  { slug: "gaming", name: "Gaming", description: "Consoles, games, and gear." },
  { slug: "books", name: "Books", description: "Education, fiction, and local titles." },
  { slug: "jewelry", name: "Jewelry", description: "Gold, beads, and everyday shine." },
  { slug: "luxury", name: "Luxury", description: "Premium watches, bags, and exclusives." },
  { slug: "furniture", name: "Furniture", description: "Home and office furniture." },
  { slug: "home-decor", name: "Home Decor", description: "Artful accents for living spaces." },
  { slug: "kitchen", name: "Kitchen", description: "Cookware, appliances, and tools." },
  { slug: "automotive", name: "Automotive", description: "Parts, accessories, and care." },
  { slug: "baby-products", name: "Baby Products", description: "Care, gear, and essentials for little ones." },
  { slug: "pet-supplies", name: "Pet Supplies", description: "Food, toys, and care for pets." },
  { slug: "sports", name: "Sports", description: "Fitness gear and outdoor kit." },
  { slug: "collectibles", name: "Collectibles", description: "Rare finds and limited editions." },
  { slug: "art", name: "Art", description: "Original works and prints." },
  { slug: "vintage", name: "Vintage", description: "Timeless second-hand treasures." },
  { slug: "handmade", name: "Handmade", description: "Crafted goods from local makers." },
  { slug: "office-supplies", name: "Office Supplies", description: "Stationery and workspace tools." },
  { slug: "industrial-equipment", name: "Industrial Equipment", description: "Tools and equipment for trade." },
  { slug: "services", name: "Services", description: "Bookable services from trusted providers." },
  { slug: "digital-products", name: "Digital Products", description: "Downloads, courses, and licenses." },
  { slug: "real-estate", name: "Real Estate", description: "Listings and property opportunities." },
  { slug: "vehicles", name: "Vehicles", description: "Cars, motorbikes, and mobility." },
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

export function categoryName(slug: ProductCategory): string {
  return CATEGORY_MAP[slug]?.name ?? slug;
}

import type { ProductCategory } from "@/types";

/** Local transparent cutouts in /public/categories */
export const CATEGORY_IMAGES: Record<ProductCategory, string> = {
  groceries: "/categories/groceries.png",
  electronics: "/categories/electronics.png",
  fashion: "/categories/fashion.png",
  shoes: "/categories/shoes.png",
  "beauty-personal-care": "/categories/beauty-personal-care.png",
  "health-wellness": "/categories/health-wellness.png",
  "home-kitchen": "/categories/home-kitchen.png",
  furniture: "/categories/furniture.png",
  "home-decor": "/categories/home-decor.png",
  appliances: "/categories/appliances.png",
  "phones-accessories": "/categories/phones-accessories.png",
  "computers-tablets": "/categories/computers-tablets.png",
  gaming: "/categories/gaming.png",
  "cameras-photography": "/categories/cameras-photography.png",
  "jewelry-watches": "/categories/jewelry-watches.png",
  "luxury-goods": "/categories/luxury-goods.png",
  "baby-kids": "/categories/baby-kids.png",
  "toys-games": "/categories/toys-games.png",
  "sports-outdoors": "/categories/sports-outdoors.png",
  automotive: "/categories/automotive.png",
  "tools-hardware": "/categories/tools-hardware.png",
  "pet-supplies": "/categories/pet-supplies.png",
  books: "/categories/books.png",
  "music-instruments": "/categories/music-instruments.png",
  "movies-entertainment": "/categories/movies-entertainment.png",
  "art-collectibles": "/categories/art-collectibles.png",
  "antiques-vintage": "/categories/antiques-vintage.png",
  "handmade-crafts": "/categories/handmade-crafts.png",
  "office-school-supplies": "/categories/office-school-supplies.png",
  "garden-outdoor": "/categories/garden-outdoor.png",
  "industrial-business-equipment":
    "/categories/industrial-business-equipment.png",
  "digital-products": "/categories/digital-products.png",
  services: "/categories/services.png",
  "real-estate": "/categories/real-estate.png",
  vehicles: "/categories/vehicles.png",
  "tickets-events": "/categories/tickets-events.png",
  "gift-cards": "/categories/gift-cards.png",
  miscellaneous: "/categories/miscellaneous.png",
};

export function categoryImage(slug: ProductCategory | string): string {
  return (
    CATEGORY_IMAGES[slug as ProductCategory] ?? CATEGORY_IMAGES.miscellaneous
  );
}

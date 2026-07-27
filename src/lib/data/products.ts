import { ALL_FULFILLMENT_MODES } from "@/lib/categories";
import type { Product, ProductBundle } from "@/types";

const allModes = [...ALL_FULFILLMENT_MODES];

const endsSoon = new Date(Date.now() + 1000 * 60 * 45).toISOString();

export const PRODUCTS: Product[] = [
  {
    id: "prod-tomatoes",
    slug: "garden-fresh-tomatoes-5kg",
    name: "Garden Fresh Tomatoes — 5kg",
    description: "Vine-ripened tomatoes from Eastern Region farms. Same-day Accra delivery.",
    category: "groceries",
    priceGhs: 85,
    compareAtGhs: 110,
    currency: "GHS",
    images: [
      "https://images.unsplash.com/photo-1546470427-e26264be0d40?auto=format&fit=crop&w=800&q=80",
    ],
    sellerId: "seller-ama-market",
    stock: 140,
    rating: 4.8,
    reviewCount: 312,
    tags: ["fresh", "farm", "live-pin"],
    flashSale: { endsAt: endsSoon, discountPct: 22 },
    supports: allModes,
  },
  {
    id: "prod-rice",
    slug: "royal-jasmine-rice-25kg",
    name: "Royal Jasmine Rice — 25kg",
    description: "Premium long-grain rice for households and chop bars.",
    category: "groceries",
    priceGhs: 420,
    compareAtGhs: 480,
    currency: "GHS",
    images: [
      "https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=800&q=80",
    ],
    sellerId: "seller-ama-market",
    stock: 86,
    rating: 4.9,
    reviewCount: 890,
    tags: ["staple", "bulk"],
    supports: allModes,
  },
  {
    id: "prod-oil",
    slug: "suncrest-cooking-oil-5l",
    name: "Suncrest Cooking Oil — 5L",
    description: "Refined vegetable oil sealed for freshness.",
    category: "groceries",
    priceGhs: 145,
    compareAtGhs: 165,
    currency: "GHS",
    images: [
      "https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=800&q=80",
    ],
    sellerId: "seller-ama-market",
    stock: 210,
    rating: 4.7,
    reviewCount: 540,
    tags: ["pantry", "kitchen"],
    supports: allModes,
  },
  {
    id: "prod-phone",
    slug: "nova-x12-smartphone",
    name: "Nova X12 Smartphone 256GB",
    description: "AMOLED display, dual SIM, Ghana warranty included.",
    category: "phones-accessories",
    priceGhs: 2899,
    compareAtGhs: 3299,
    currency: "GHS",
    images: [
      "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=800&q=80",
    ],
    sellerId: "seller-ama-market",
    stock: 24,
    rating: 4.6,
    reviewCount: 188,
    tags: ["gadgets", "auction-ready"],
    flashSale: { endsAt: endsSoon, discountPct: 12 },
    supports: allModes,
  },
  {
    id: "prod-sneakers",
    slug: "accra-runner-sneakers",
    name: "Accra Runner Sneakers",
    description: "Breathable city sneakers in forest green and gold accents.",
    category: "shoes",
    priceGhs: 380,
    compareAtGhs: 450,
    currency: "GHS",
    images: [
      "https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=800&q=80",
    ],
    sellerId: "seller-ama-market",
    stock: 55,
    rating: 4.5,
    reviewCount: 267,
    tags: ["streetwear"],
    supports: allModes,
  },
  {
    id: "prod-watch",
    slug: "goldline-chrono-watch",
    name: "Goldline Chrono Watch",
    description: "Stainless chronograph with Ghana-gold dial detailing.",
    category: "jewelry-watches",
    priceGhs: 1650,
    compareAtGhs: 2100,
    currency: "GHS",
    images: [
      "https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=800&q=80",
    ],
    sellerId: "seller-ama-market",
    stock: 12,
    rating: 4.8,
    reviewCount: 96,
    tags: ["luxury", "gift"],
    supports: allModes,
  },
  {
    id: "prod-kente",
    slug: "handwoven-kente-stole",
    name: "Handwoven Kente Stole",
    description: "Authentic Ashanti weave — each piece unique.",
    category: "handmade-crafts",
    priceGhs: 720,
    currency: "GHS",
    images: [
      "https://images.unsplash.com/photo-1594736797933-d0501ba2fe65?auto=format&fit=crop&w=800&q=80",
    ],
    sellerId: "seller-kumasi-craft",
    stock: 18,
    rating: 5,
    reviewCount: 74,
    tags: ["heritage", "auction"],
    supports: allModes,
  },
  {
    id: "prod-beads",
    slug: "glass-bead-necklace-set",
    name: "Glass Bead Necklace Set",
    description: "Handmade beadwork in warm coastal tones.",
    category: "jewelry-watches",
    priceGhs: 240,
    currency: "GHS",
    images: [
      "https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=800&q=80",
    ],
    sellerId: "seller-kumasi-craft",
    stock: 40,
    rating: 4.9,
    reviewCount: 151,
    tags: ["gift", "handmade"],
    supports: allModes,
  },
  {
    id: "prod-laptop",
    slug: "harborbook-pro-14",
    name: "HarborBook Pro 14",
    description: "Ultralight laptop for creators and founders.",
    category: "computers-tablets",
    priceGhs: 6499,
    compareAtGhs: 7199,
    currency: "GHS",
    images: [
      "https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=800&q=80",
    ],
    sellerId: "seller-tech-harbor",
    stock: 9,
    rating: 4.7,
    reviewCount: 63,
    tags: ["work", "live-demo"],
    flashSale: { endsAt: endsSoon, discountPct: 10 },
    supports: allModes,
  },
  {
    id: "prod-console",
    slug: "pulse-station-slim",
    name: "Pulse Station Slim Console",
    description: "1TB console bundle with wireless controller.",
    category: "gaming",
    priceGhs: 4200,
    currency: "GHS",
    images: [
      "https://images.unsplash.com/photo-1606144042614-b2417e99c4e3?auto=format&fit=crop&w=800&q=80",
    ],
    sellerId: "seller-tech-harbor",
    stock: 15,
    rating: 4.8,
    reviewCount: 120,
    tags: ["gaming"],
    supports: allModes,
  },
  {
    id: "prod-tilapia",
    slug: "fresh-tilapia-tray",
    name: "Fresh Tilapia Tray — 2kg",
    description: "Cleaned and packed for same-day chilled delivery.",
    category: "groceries",
    priceGhs: 95,
    currency: "GHS",
    images: [
      "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=800&q=80",
    ],
    sellerId: "seller-coastal-catch",
    stock: 60,
    rating: 4.6,
    reviewCount: 203,
    tags: ["fresh", "cold-chain"],
    supports: allModes,
  },
  {
    id: "prod-blender",
    slug: "coastal-power-blender",
    name: "Coastal Power Blender",
    description: "High-torque blender for soups, juices, and mill work.",
    category: "appliances",
    priceGhs: 560,
    compareAtGhs: 640,
    currency: "GHS",
    images: [
      "https://images.unsplash.com/photo-1570222094114-d054a817e56b?auto=format&fit=crop&w=800&q=80",
    ],
    sellerId: "seller-coastal-catch",
    stock: 33,
    rating: 4.5,
    reviewCount: 88,
    tags: ["appliance"],
    supports: allModes,
  },
  {
    id: "prod-bread",
    slug: "overnight-butter-loaf",
    name: "Overnight Butter Loaf",
    description: "Baked at dawn, soft crumb, Accra morning drop.",
    category: "groceries",
    priceGhs: 28,
    currency: "GHS",
    images: [
      "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=800&q=80",
    ],
    sellerId: "seller-ama-market",
    stock: 90,
    rating: 4.9,
    reviewCount: 410,
    tags: ["fresh"],
    supports: allModes,
  },
  {
    id: "prod-yogurt",
    slug: "plain-cultured-yogurt-1l",
    name: "Cultured Yogurt — 1L",
    description: "Chilled dairy staple for breakfast and cooking.",
    category: "groceries",
    priceGhs: 42,
    currency: "GHS",
    images: [
      "https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=800&q=80",
    ],
    sellerId: "seller-ama-market",
    stock: 120,
    rating: 4.4,
    reviewCount: 76,
    tags: ["chilled"],
    supports: allModes,
  },
  {
    id: "prod-sofa",
    slug: "accra-lounge-sofa",
    name: "Accra Lounge Sofa",
    description: "Three-seater fabric sofa with local artisan frame.",
    category: "furniture",
    priceGhs: 4800,
    currency: "GHS",
    images: [
      "https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=800&q=80",
    ],
    sellerId: "seller-kumasi-craft",
    stock: 4,
    rating: 4.7,
    reviewCount: 22,
    tags: ["home"],
    supports: allModes,
  },
];

export const BUNDLES: ProductBundle[] = [
  {
    id: "bundle-sunday-cook",
    name: "Sunday Cook Bundle",
    productIds: ["prod-tomatoes", "prod-rice", "prod-oil"],
    priceGhs: 580,
    sellerId: "seller-ama-market",
  },
  {
    id: "bundle-street-fit",
    name: "Street Fit Bundle",
    productIds: ["prod-sneakers", "prod-watch"],
    priceGhs: 1850,
    sellerId: "seller-ama-market",
  },
];

export function getProduct(id: string) {
  return PRODUCTS.find((p) => p.id === id);
}

export function getProductBySlug(slug: string) {
  return PRODUCTS.find((p) => p.slug === slug);
}

export function getProductsBySeller(sellerId: string) {
  return PRODUCTS.filter((p) => p.sellerId === sellerId);
}

export function getProductsByCategory(category: string) {
  return PRODUCTS.filter((p) => p.category === category);
}

export function getFlashSaleProducts() {
  return PRODUCTS.filter((p) => p.flashSale);
}

export function getEffectivePrice(product: Product): number {
  if (!product.flashSale) return product.priceGhs;
  return Math.round(product.priceGhs * (1 - product.flashSale.discountPct / 100));
}

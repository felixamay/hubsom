import type { Seller } from "@/types";

export const SELLERS: Seller[] = [
  {
    id: "seller-ama-market",
    slug: "ama-market-live",
    name: "Ama Market Live",
    city: "Accra",
    region: "Greater Accra",
    bio: "One stream, every aisle — fresh produce, pantry, fashion, and gadgets from Makola to your door.",
    avatar:
      "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?auto=format&fit=crop&w=200&q=80",
    cover:
      "https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?auto=format&fit=crop&w=1600&q=80",
    rating: 4.9,
    followers: 128400,
    verified: true,
    categories: [
      "fresh-produce",
      "groceries",
      "pantry-staples",
      "fashion",
      "electronics",
      "shoes",
    ],
  },
  {
    id: "seller-kumasi-craft",
    slug: "kumasi-craft-house",
    name: "Kumasi Craft House",
    city: "Kumasi",
    region: "Ashanti",
    bio: "Handmade textiles, jewelry, and home decor — auctioned live from the Ashanti capital.",
    avatar:
      "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=200&q=80",
    cover:
      "https://images.unsplash.com/photo-1452860606245-08befc0ff44b?auto=format&fit=crop&w=1600&q=80",
    rating: 4.8,
    followers: 64200,
    verified: true,
    categories: ["handmade", "jewelry", "home-decor", "art", "fashion"],
  },
  {
    id: "seller-tech-harbor",
    slug: "tech-harbor-gh",
    name: "Tech Harbor GH",
    city: "Tema",
    region: "Greater Accra",
    bio: "Phones, laptops, and gaming gear with live demos and flash drops.",
    avatar:
      "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80",
    cover:
      "https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=1600&q=80",
    rating: 4.7,
    followers: 89100,
    verified: true,
    categories: ["electronics", "computers", "gaming", "luxury"],
  },
  {
    id: "seller-coastal-catch",
    slug: "coastal-catch",
    name: "Coastal Catch",
    city: "Cape Coast",
    region: "Central",
    bio: "Seafood, frozen foods, and kitchen gear shipped cold-chain nationwide.",
    avatar:
      "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=200&q=80",
    cover:
      "https://images.unsplash.com/photo-1559339352-11d035aa65de?auto=format&fit=crop&w=1600&q=80",
    rating: 4.6,
    followers: 31800,
    verified: true,
    categories: ["meat-seafood", "frozen-foods", "kitchen", "groceries"],
  },
];

export function getSeller(id: string) {
  return SELLERS.find((s) => s.id === id);
}

export function getSellerBySlug(slug: string) {
  return SELLERS.find((s) => s.slug === slug);
}

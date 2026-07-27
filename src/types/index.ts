export type ProductCategory =
  | "groceries"
  | "electronics"
  | "fashion"
  | "shoes"
  | "beauty-personal-care"
  | "health-wellness"
  | "home-kitchen"
  | "furniture"
  | "home-decor"
  | "appliances"
  | "phones-accessories"
  | "computers-tablets"
  | "gaming"
  | "cameras-photography"
  | "jewelry-watches"
  | "luxury-goods"
  | "baby-kids"
  | "toys-games"
  | "sports-outdoors"
  | "automotive"
  | "tools-hardware"
  | "pet-supplies"
  | "books"
  | "music-instruments"
  | "movies-entertainment"
  | "art-collectibles"
  | "antiques-vintage"
  | "handmade-crafts"
  | "office-school-supplies"
  | "garden-outdoor"
  | "industrial-business-equipment"
  | "digital-products"
  | "services"
  | "real-estate"
  | "vehicles"
  | "tickets-events"
  | "gift-cards"
  | "miscellaneous";

export type FulfillmentMode =
  | "buy-now"
  | "live-selling"
  | "live-auction"
  | "flash-sale"
  | "bundle"
  | "store-listing"
  | "promotion";

export interface CategoryMeta {
  slug: ProductCategory;
  name: string;
  description: string;
}

export interface Seller {
  id: string;
  slug: string;
  name: string;
  city: string;
  region: string;
  bio: string;
  avatar: string;
  cover: string;
  rating: number;
  followers: number;
  verified: boolean;
  categories: ProductCategory[];
}

export interface Product {
  id: string;
  slug: string;
  name: string;
  description: string;
  category: ProductCategory;
  priceGhs: number;
  compareAtGhs?: number;
  currency: "GHS";
  images: string[];
  sellerId: string;
  stock: number;
  rating: number;
  reviewCount: number;
  tags: string[];
  bundleIds?: string[];
  flashSale?: {
    endsAt: string;
    discountPct: number;
  };
  supports: FulfillmentMode[];
}

export interface ProductBundle {
  id: string;
  name: string;
  productIds: string[];
  priceGhs: number;
  sellerId: string;
}

export type StreamStatus = "scheduled" | "live" | "ended" | "replay";

export interface StreamHost {
  id: string;
  name: string;
  role: "host" | "guest" | "moderator";
  avatar: string;
}

export interface LiveAuction {
  id: string;
  productId: string;
  startingBidGhs: number;
  currentBidGhs: number;
  minIncrementGhs: number;
  endsAt: string;
  bidderCount: number;
  highestBidder?: string;
  status: "upcoming" | "open" | "closing" | "sold" | "unsold";
}

export interface LiveStream {
  id: string;
  title: string;
  description: string;
  sellerId: string;
  status: StreamStatus;
  channelName: string;
  cover: string;
  viewerCount: number;
  peakViewers: number;
  startedAt?: string;
  endedAt?: string;
  recordingUrl?: string;
  productIds: string[];
  pinnedProductId?: string;
  hosts: StreamHost[];
  auction?: LiveAuction;
  categories: ProductCategory[];
  latencyMs: number;
  isMultiHost: boolean;
  replayAvailable: boolean;
}

export interface ChatMessage {
  id: string;
  streamId: string;
  userId: string;
  displayName: string;
  text: string;
  createdAt: string;
  moderated?: boolean;
}

export interface LiveReaction {
  id: string;
  streamId: string;
  emoji: string;
  x: number;
  createdAt: number;
}

export interface CartItem {
  productId: string;
  quantity: number;
  source: "buy-now" | "live" | "auction" | "flash-sale" | "bundle";
  streamId?: string;
  /** Snapshot at add-time so the cart works without catalog hydration */
  name: string;
  priceGhs: number;
  image?: string;
  category?: ProductCategory;
}

export interface ViewerAnalytics {
  streamId: string;
  concurrent: number;
  avgWatchSeconds: number;
  chatMessages: number;
  reactions: number;
  checkouts: number;
  conversionRate: number;
}

export interface SellerAnalytics {
  streamId: string;
  revenueGhs: number;
  unitsSold: number;
  uniqueBuyers: number;
  peakConcurrent: number;
  avgLatencyMs: number;
  inventorySyncEvents: number;
}

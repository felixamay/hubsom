import type { ChatMessage, LiveStream, SellerAnalytics, ViewerAnalytics } from "@/types";

const auctionEnds = new Date(Date.now() + 1000 * 60 * 8).toISOString();

export const STREAMS: LiveStream[] = [
  {
    id: "stream-ama-mix",
    title: "Makola Mix Live — Produce, Pantry & Gadgets",
    description:
      "One show, every category: tomatoes, rice, oil, phones, sneakers, and watches. Pin, bid, or buy while watching.",
    sellerId: "seller-ama-market",
    status: "live",
    channelName: "hubsom_ama_mix_live",
    cover:
      "https://images.unsplash.com/photo-1604719312566-8912e9227c6a?auto=format&fit=crop&w=1600&q=80",
    viewerCount: 3842,
    peakViewers: 5120,
    startedAt: new Date(Date.now() - 1000 * 60 * 34).toISOString(),
    productIds: [
      "prod-tomatoes",
      "prod-rice",
      "prod-oil",
      "prod-phone",
      "prod-sneakers",
      "prod-watch",
      "prod-bread",
      "prod-yogurt",
    ],
    pinnedProductId: "prod-tomatoes",
    hosts: [
      {
        id: "host-ama",
        name: "Ama Mensah",
        role: "host",
        avatar:
          "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?auto=format&fit=crop&w=200&q=80",
      },
      {
        id: "guest-kojo",
        name: "Kojo Addo",
        role: "guest",
        avatar:
          "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=200&q=80",
      },
      {
        id: "mod-efua",
        name: "Efua Darko",
        role: "moderator",
        avatar:
          "https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80",
      },
    ],
    auction: {
      id: "auction-phone",
      productId: "prod-phone",
      startingBidGhs: 2400,
      currentBidGhs: 2680,
      minIncrementGhs: 20,
      endsAt: auctionEnds,
      bidderCount: 47,
      highestBidder: "NanaK",
      status: "open",
    },
    categories: [
      "groceries",
      "phones-accessories",
      "shoes",
      "jewelry-watches",
      "electronics",
    ],
    latencyMs: 980,
    isMultiHost: true,
    replayAvailable: true,
  },
  {
    id: "stream-kente-night",
    title: "Kente Night Auction",
    description: "Handwoven textiles and jewelry — live bidding from Kumasi.",
    sellerId: "seller-kumasi-craft",
    status: "live",
    channelName: "hubsom_kente_night",
    cover:
      "https://images.unsplash.com/photo-1523381210414-8a6c6a5e5c4a?auto=format&fit=crop&w=1600&q=80",
    viewerCount: 1260,
    peakViewers: 1800,
    startedAt: new Date(Date.now() - 1000 * 60 * 18).toISOString(),
    productIds: ["prod-kente", "prod-beads", "prod-sofa"],
    pinnedProductId: "prod-kente",
    hosts: [
      {
        id: "host-yaa",
        name: "Yaa Boateng",
        role: "host",
        avatar:
          "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=200&q=80",
      },
    ],
    auction: {
      id: "auction-kente",
      productId: "prod-kente",
      startingBidGhs: 500,
      currentBidGhs: 780,
      minIncrementGhs: 25,
      endsAt: new Date(Date.now() + 1000 * 60 * 12).toISOString(),
      bidderCount: 29,
      highestBidder: "AbenaO",
      status: "open",
    },
    categories: [
      "handmade-crafts",
      "jewelry-watches",
      "furniture",
      "art-collectibles",
    ],
    latencyMs: 1100,
    isMultiHost: false,
    replayAvailable: true,
  },
  {
    id: "stream-tech-drop",
    title: "Tech Harbor Flash Drop",
    description: "Laptops and consoles with live demos and one-tap checkout.",
    sellerId: "seller-tech-harbor",
    status: "scheduled",
    channelName: "hubsom_tech_drop",
    cover:
      "https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=1600&q=80",
    viewerCount: 0,
    peakViewers: 0,
    productIds: ["prod-laptop", "prod-console", "prod-phone"],
    hosts: [
      {
        id: "host-kwesi",
        name: "Kwesi Boat",
        role: "host",
        avatar:
          "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80",
      },
    ],
    categories: ["computers-tablets", "gaming", "phones-accessories", "electronics"],
    latencyMs: 0,
    isMultiHost: false,
    replayAvailable: false,
  },
  {
    id: "stream-coastal-replay",
    title: "Coastal Catch Morning Run",
    description: "Seafood and kitchen gear — replay with shoppable moments.",
    sellerId: "seller-coastal-catch",
    status: "replay",
    channelName: "hubsom_coastal_replay",
    cover:
      "https://images.unsplash.com/photo-1559339352-11d035aa65de?auto=format&fit=crop&w=1600&q=80",
    viewerCount: 420,
    peakViewers: 2100,
    startedAt: new Date(Date.now() - 1000 * 60 * 60 * 20).toISOString(),
    endedAt: new Date(Date.now() - 1000 * 60 * 60 * 18).toISOString(),
    recordingUrl: "https://example.com/replays/coastal-catch.m3u8",
    productIds: ["prod-tilapia", "prod-blender", "prod-oil"],
    pinnedProductId: "prod-tilapia",
    hosts: [
      {
        id: "host-akua",
        name: "Akua Essel",
        role: "host",
        avatar:
          "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=200&q=80",
      },
    ],
    categories: ["groceries", "appliances", "home-kitchen"],
    latencyMs: 0,
    isMultiHost: false,
    replayAvailable: true,
  },
];

export const SEED_CHAT: ChatMessage[] = [
  {
    id: "c1",
    streamId: "stream-ama-mix",
    userId: "u1",
    displayName: "AmaK",
    text: "Those tomatoes look fire 🔥",
    createdAt: new Date(Date.now() - 40000).toISOString(),
  },
  {
    id: "c2",
    streamId: "stream-ama-mix",
    userId: "u2",
    displayName: "KofiTech",
    text: "Bidding on the Nova X12!",
    createdAt: new Date(Date.now() - 28000).toISOString(),
  },
  {
    id: "c3",
    streamId: "stream-ama-mix",
    userId: "u3",
    displayName: "EfuaM",
    text: "One-tap checkout for the rice + oil bundle?",
    createdAt: new Date(Date.now() - 15000).toISOString(),
  },
  {
    id: "c4",
    streamId: "stream-ama-mix",
    userId: "u4",
    displayName: "NanaK",
    text: "Just pinned sneakers for me?",
    createdAt: new Date(Date.now() - 8000).toISOString(),
  },
];

export const VIEWER_ANALYTICS: ViewerAnalytics[] = [
  {
    streamId: "stream-ama-mix",
    concurrent: 3842,
    avgWatchSeconds: 412,
    chatMessages: 18220,
    reactions: 54010,
    checkouts: 896,
    conversionRate: 0.233,
  },
];

export const SELLER_ANALYTICS: SellerAnalytics[] = [
  {
    streamId: "stream-ama-mix",
    revenueGhs: 186420,
    unitsSold: 1240,
    uniqueBuyers: 896,
    peakConcurrent: 5120,
    avgLatencyMs: 980,
    inventorySyncEvents: 3180,
  },
];

export function getStream(id: string) {
  return STREAMS.find((s) => s.id === id);
}

export function getLiveStreams() {
  return STREAMS.filter((s) => s.status === "live");
}

export function getStreamsBySeller(sellerId: string) {
  return STREAMS.filter((s) => s.sellerId === sellerId);
}

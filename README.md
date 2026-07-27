# Hubsom

Ghana-based social-commerce platform for **live shopping**, **live auctions**, **Buy Now marketplace**, **flash sales**, and **seller stores**.

There is **no dedicated grocery marketplace**. Groceries, fashion, electronics, and every other category share the same commerce surfaces:

- Buy Now
- Live selling
- Live auctions
- Flash sales
- Product bundles
- Store listings
- Promotions

## Stack

- **Next.js** (App Router) + TypeScript + Tailwind CSS
- **Agora RTC** for ultra-low-latency live video (adaptive bitrate, HD/FHD)
- Zustand cart + live UI state
- Framer Motion for hero presence
- Durable local persistence under `.data/` (products, sellers, streams, chat, orders)

## Quick start

```bash
npm install
cp .env.example .env.local
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

The catalog starts empty. Production flow:

1. **Sell → Add listing** (`/seller/products/new`) — create real products
2. **Sell → Go live** (`/seller/go-live`) — select catalog items and start a show
3. Watchers join `/live/[id]`; hosts use `?host=1`

### Agora (required for camera)

| Variable | Required | Where to get it |
| --- | --- | --- |
| `NEXT_PUBLIC_AGORA_APP_ID` | **Yes** | [Agora Console](https://console.agora.io) → Project → **App ID** |
| `AGORA_APP_CERTIFICATE` | **Yes (recommended)** | Project → **App Certificate** → enable & copy primary |

Without Agora credentials, go-live still creates the show room, but video reports **Camera offline**. Check `/api/agora/status`.

## Key routes

| Route | Purpose |
| --- | --- |
| `/` | Brand hero + live + marketplace entry |
| `/live` | Browse shows |
| `/live/[id]` | Live commerce room (add `?host=1` for host mode) |
| `/marketplace` | Buy Now catalog |
| `/categories/[slug]` | Unified category pages |
| `/auctions` | Live auctions index |
| `/flash-sales` | Timed drops |
| `/stores/[slug]` | Seller stores |
| `/seller/products/new` | Create catalog listings |
| `/seller/go-live` | Launch a live show from your catalog |
| `/seller/analytics` | Revenue + viewer analytics from real orders |
| `/dashboard` | Performance overview |

## Live commerce capabilities

- Ultra-low latency target (&lt;2s) via Agora
- Adaptive bitrate, HD / Full HD
- Persisted chat + moderation heuristic
- Floating hearts / emoji reactions
- Product pinning + on-demand shopping bag
- Live cart + checkout with stock reservation
- Live auctions with countdown bidding
- Multi-host / guest seller controls
- Moderator panel
- Picture-in-picture
- Stream recording / replay hooks
- Inventory sync API
- Analytics derived from orders + live streams

## Data

Runtime data is written to `.data/` (gitignored):

- `products.json` · `sellers.json` · `live-streams.json` · `chat.json` · `orders.json`

Swap these JSON stores for a managed database before multi-instance production deploy.

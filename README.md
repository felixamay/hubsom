# Hubsom

Ghana-based social-commerce platform for **live shopping**, **live auctions**, **Buy Now marketplace**, **flash sales**, and **seller stores**.

There is **no dedicated grocery marketplace**. Groceries, fresh produce, fashion, electronics, and every other category share the same commerce surfaces:

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

## Quick start

```bash
npm install
cp .env.example .env.local
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

### Agora (production live video)

1. Create a project in the [Agora Console](https://console.agora.io).
2. Set `NEXT_PUBLIC_AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` in `.env.local`.
3. Restart the dev server.

Without credentials, the live room uses Hubsom’s demo engine UI while the rest of the commerce stack (chat, reactions, pinning, auctions, cart, inventory sync) remains fully interactive.

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
| `/seller/go-live` | Launch a mixed-category show |
| `/seller/analytics` | Viewer + seller analytics |

## Live commerce capabilities

- Ultra-low latency target (&lt;2s) via Agora
- Adaptive bitrate, HD / Full HD
- Realtime chat + AI moderation heuristic
- Floating hearts / emoji reactions
- Product pinning + live product carousel
- Live cart + one-tap checkout
- Live auctions with countdown bidding
- Multi-host / guest seller controls
- Moderator panel
- Picture-in-picture
- Stream recording / replay hooks
- Realtime inventory sync API
- Viewer & seller analytics
- Designed for auto-scale toward 10,000+ concurrent viewers

## Example mixed show

`/live/stream-ama-mix` sells tomatoes, rice, cooking oil, phones, sneakers, and watches in **one** stream — identical flows per category.

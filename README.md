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

Provide these so hosts can go live with real camera/mic:

| Variable | Required | Where to get it |
| --- | --- | --- |
| `NEXT_PUBLIC_AGORA_APP_ID` | **Yes** | [Agora Console](https://console.agora.io) → Project → **App ID** |
| `AGORA_APP_CERTIFICATE` | **Yes (recommended)** | Project → **App Certificate** → enable & copy primary |

```bash
cp .env.example .env.local
# paste App ID + Certificate, then:
npm run dev
```

Then open **Sell → Go live → Start show as host** and allow camera/mic.

Without credentials, commerce features still work (chat, pin, auction, cart); video stays in demo mode. Check `/api/agora/status` for current config.

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

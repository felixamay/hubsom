# Hubsom ↔ Huber integration contract

Use this document to wire **Huber** (delivery / riders) to **Hubsom** (live commerce checkout + seller dispatch).

## Hubsom repository (share with the Huber agent)

| Field | Value |
| --- | --- |
| **Repo** | https://github.com/felixamay/hubsom |
| **Clone** | `git clone https://github.com/felixamay/hubsom.git` |
| **Working branch** | `cursor/hubsom-live-commerce-8a7a` |
| **PR** | https://github.com/felixamay/hubsom/pull/1 |
| **Default base** | `main` |

Stack: Next.js App Router, Auth.js, JSON file store under `.data/` (prototype).

---

## Goal

When a Hubsom seller consolidates purchases into a shipment and presses **Hubers**:

1. Hubsom creates delivery **offers** for approved riders.
2. Huber receives those offers (push/API).
3. A rider **accepts** → Huber notifies Hubsom.
4. Hubsom marks the shipment **assigned** and tracks delivery status from Huber.

Checkout already captures buyer shipping + optional GPS pin. Sellers can also pin location before dispatch.

---

## Hubsom domain models (source of truth)

Types live in [`src/types/orders.ts`](../src/types/orders.ts).

### Order (purchase)

- Created by `POST /api/checkout`
- Has `shipping` (address + optional `location: { latitude, longitude, … }`)
- Status: `pending_payment | paid | fulfilled | cancelled`

### Shipment (consolidated dispatch)

- Created by seller: `POST /api/seller/shipments` with `{ orderIds: string[] }`
- Status: `draft | ready | offering | assigned | out_for_delivery | delivered | cancelled`
- Requires `destination.location` before Hubers offers can be sent

### DeliveryOffer

```ts
{
  id: string
  shipmentId: string
  huberId: string
  huberName: string
  status: "queued" | "sent" | "accepted" | "declined" | "expired"
  offeredFeeGhs?: number
  providerReference?: string  // Huber’s job/offer id once live
  createdAt: string
  expiresAt: string
}
```

---

## APIs Huber should use / implement against

### A. Hubsom → Huber (outbound, to implement for real)

Today stubbed in [`src/lib/hubers/client.ts`](../src/lib/hubers/client.ts).

When live, Hubsom will `POST` to Huber:

```http
POST {HUBERS_API_BASE_URL}/v1/delivery-offers
Authorization: Bearer {HUBERS_API_KEY}
Content-Type: application/json
```

**Payload Hubsom sends:**

```json
{
  "source": "hubsom",
  "event": "delivery_offers.create",
  "shipmentId": "shp_…",
  "preferredFeeGhs": 25,
  "expiresAt": "ISO-8601",
  "pickup": {
    "label": "Seller store / pickup",
    "sellerId": "seller-…",
    "city": "Accra",
    "region": "Greater Accra"
  },
  "dropoff": {
    "recipientName": "…",
    "phone": "024…",
    "line1": "…",
    "line2": "…",
    "city": "Accra",
    "region": "Greater Accra",
    "notes": "…",
    "location": {
      "latitude": 5.6037,
      "longitude": -0.187,
      "accuracyM": 12,
      "source": "gps"
    }
  },
  "items": [
    {
      "orderId": "ord_…",
      "productId": "prod-…",
      "name": "…",
      "quantity": 1,
      "lineTotalGhs": 120
    }
  ],
  "currency": "GHS"
}
```

**Expected Huber response:**

```json
{
  "ok": true,
  "offers": [
    {
      "huberOfferId": "huber_off_…",
      "riderId": "rider_…",
      "riderName": "Ama Mensah",
      "status": "sent",
      "expiresAt": "ISO-8601"
    }
  ]
}
```

Env vars Hubsom will use (add when connecting):

```bash
HUBERS_API_BASE_URL=https://api.huber.example
HUBERS_API_KEY=…
HUBERS_WEBHOOK_SECRET=…
```

### B. Huber → Hubsom (webhooks — implement on Hubsom)

Endpoint (implemented stub):

```http
POST /api/integrations/hubers/webhook
Content-Type: application/json
X-Hubers-Signature: sha256=…   # HMAC of raw body with HUBERS_WEBHOOK_SECRET
```

**Events Huber should send:**

| event | When | Required fields |
| --- | --- | --- |
| `offer.accepted` | Rider accepts | `shipmentId`, `offerId` or `providerReference`, `riderId`, `riderName` |
| `offer.declined` | Rider declines | `shipmentId`, `offerId` |
| `offer.expired` | Offer timed out | `shipmentId`, `offerId` |
| `delivery.picked_up` | Package collected | `shipmentId` |
| `delivery.out_for_delivery` | En route | `shipmentId` |
| `delivery.delivered` | Dropped off | `shipmentId` |
| `delivery.cancelled` | Failed / cancelled | `shipmentId`, `reason?` |

**Example:**

```json
{
  "source": "huber",
  "event": "offer.accepted",
  "shipmentId": "shp_…",
  "offerId": "off_…",
  "providerReference": "huber_off_…",
  "riderId": "rider_…",
  "riderName": "Ama Mensah",
  "occurredAt": "ISO-8601"
}
```

Hubsom maps:

- `offer.accepted` → shipment `assigned` + `assignedHuberId/Name`, offer `accepted`
- `delivery.out_for_delivery` → `out_for_delivery`
- `delivery.delivered` → `delivered`
- `delivery.cancelled` → `cancelled`

### C. Seller-facing Hubsom routes (already live)

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/api/checkout` | Buyer checkout (creates order + shipping pin) |
| `POST` | `/api/seller/shipments` | Consolidate order ids into a shipment |
| `PATCH` | `/api/seller/shipments/:id` | Update destination / location pin |
| `POST` | `/api/seller/shipments/:id/hubers` | Send offers to Hubers (calls adapter) |

Auth: session cookie (Auth.js). Integration calls should use `HUBERS_API_KEY` / webhook secret, not browser sessions.

---

## Checkout auto-wire (recommended for Huber agent)

1. After Hubsom checkout (or when seller marks paid), optionally auto-create a draft shipment for that seller’s lines.
2. If `shipping.location` exists, mark shipment `ready`.
3. Call Hubers `delivery_offers.create` automatically **or** keep seller “Hubers” button as the explicit trigger (current UX).
4. Persist Huber `huberOfferId` into `DeliveryOffer.providerReference`.
5. Drive status only via Huber webhooks (single source of truth for rider progress).

Suggested first milestone: **manual Hubers button → real HTTP to Huber → webhook accept/delivered**.  
Second milestone: auto-dispatch after paid checkout when pin exists.

---

## Key Hubsom files for the other AI

| Path | Role |
| --- | --- |
| `src/lib/hubers/client.ts` | Outbound adapter (replace stub with fetch to Huber) |
| `src/app/api/integrations/hubers/webhook/route.ts` | Inbound status webhooks |
| `src/lib/data/shipments.ts` | Shipment + offer persistence |
| `src/types/orders.ts` | Shared types |
| `src/app/api/checkout/route.ts` | Checkout / shipping snapshot |
| `src/components/seller/SellerOrdersBoard.tsx` | Seller UI: consolidate, Locate, Hubers |
| `docs/HUBERS_INTEGRATION.md` | This contract |

---

## Prompt snippet for the Huber-side AI

Paste this into the Huber agent:

```text
Connect the Huber delivery app to Hubsom live commerce.

Hubsom repo: https://github.com/felixamay/hubsom
Branch: cursor/hubsom-live-commerce-8a7a
Contract: docs/HUBERS_INTEGRATION.md

Implement:
1) POST /v1/delivery-offers — accept Hubsom shipment dropoff+items and fan out to approved riders
2) Webhooks back to Hubsom POST /api/integrations/hubers/webhook for accept / en-route / delivered
3) Store hubsom shipmentId + offer ids; return huberOfferId as providerReference

Do not change Hubsom checkout UX; wire the delivery layer so seller “Hubers” (and later auto-checkout dispatch) works end-to-end.
```

# Hubsom ↔ HubsomAdmin promotions contract

Wire **[hubsomadmin](https://github.com/felixamay/hubsomadmin)** so promotions created there appear on Hubsom storefront slots the admin selects.

## Repos

| App | Repo | Role |
| --- | --- | --- |
| Storefront | https://github.com/felixamay/hubsom · branch `cursor/hubsom-live-commerce-8a7a` | Renders promotions |
| Admin | https://github.com/felixamay/hubsomadmin | Create / edit / target promotions |

---

## Placements admin can select

| `placements[]` value | Where it shows on Hubsom |
| --- | --- |
| `landing` | Home / landing page promo rail |
| `marketplace` | Marketplace (products listing) |
| `category` | Category browse + category detail pages |
| `product` | Product detail pages |

### Targeting rules

- **`categorySlugs: string[]`** — only when `category` (and optionally `product`) is selected.  
  - Empty / omitted → show on **all** category pages.  
  - Set → only those category slugs (e.g. `fashion`, `phones-accessories`).
- **`productIds: string[]`** — only when `product` is selected.  
  - Empty / omitted → show on **all** product pages.  
  - Set → only those product ids.

A promotion can include multiple placements at once (e.g. `["landing","category"]`).

---

## Env (both apps)

```bash
# Hubsom (.env.local)
HUBSOM_ADMIN_API_KEY=shared-secret-here

# HubsomAdmin
HUBSOM_API_BASE_URL=https://<hubsom-host>   # e.g. http://localhost:3000
HUBSOM_ADMIN_API_KEY=shared-secret-here     # same value
```

Auth header on admin → Hubsom calls:

```http
X-Hubsom-Admin-Key: <HUBSOM_ADMIN_API_KEY>
# or
Authorization: Bearer <HUBSOM_ADMIN_API_KEY>
```

If `HUBSOM_ADMIN_API_KEY` is unset on Hubsom in non-production, admin routes allow unauthenticated access for local prototyping.

---

## Hubsom APIs for admin

### 1) Catalog pickers

```http
GET /api/admin/catalog
X-Hubsom-Admin-Key: …
```

Returns:

```json
{
  "placements": [
    { "id": "landing", "label": "Landing page", "description": "…" },
    { "id": "marketplace", "label": "Marketplace / products", "description": "…" },
    { "id": "category", "label": "Category pages", "description": "…" },
    { "id": "product", "label": "Product pages", "description": "…" }
  ],
  "categories": [{ "slug": "fashion", "name": "Fashion", "description": "…" }],
  "products": [
    {
      "id": "prod-…",
      "slug": "…",
      "name": "…",
      "category": "fashion",
      "image": "…",
      "priceGhs": 120
    }
  ]
}
```

### 2) List promotions

```http
GET /api/admin/promotions
X-Hubsom-Admin-Key: …
```

### 3) Create / upsert one

```http
POST /api/admin/promotions
X-Hubsom-Admin-Key: …
Content-Type: application/json

{
  "promotion": {
    "title": "Weekend live drops",
    "subtitle": "Limited stock from live sellers",
    "ctaLabel": "Watch live",
    "href": "/live",
    "tone": "live",
    "placements": ["landing", "marketplace"],
    "categorySlugs": [],
    "productIds": [],
    "imageUrl": "https://…",
    "sortOrder": 10,
    "active": true,
    "startsAt": null,
    "endsAt": null
  }
}
```

### 4) Update one

```http
PUT /api/admin/promotions?id=promo_abc
X-Hubsom-Admin-Key: …
Content-Type: application/json

{ "title": "…", "href": "/flash-sales", "placements": ["landing"], "active": true }
```

### 5) Delete one

```http
DELETE /api/admin/promotions?id=promo_abc
X-Hubsom-Admin-Key: …
```

### 6) Replace entire catalog (sync)

```http
POST /api/admin/promotions
X-Hubsom-Admin-Key: …
Content-Type: application/json

{ "promotions": [ { "id": "promo_1", "title": "…", "href": "/…", "placements": ["landing"] } ] }
```

### 7) Public storefront feed (optional for admin preview)

```http
GET /api/promotions?placement=landing
GET /api/promotions?placement=category&category=fashion
GET /api/promotions?placement=product&productId=prod-…&category=fashion
GET /api/promotions?placement=marketplace
```

No admin key required.

---

## Promotion object

```ts
{
  id: string
  title: string
  subtitle: string
  ctaLabel: string
  href: string                 // Hubsom path or absolute URL
  tone: "forest" | "gold" | "cyan" | "live"
  placements: ("landing" | "marketplace" | "category" | "product")[]
  categorySlugs?: string[]     // target categories
  productIds?: string[]        // target products
  imageUrl?: string
  sortOrder?: number           // lower = first
  active: boolean
  startsAt?: string            // ISO
  endsAt?: string
  source?: "admin" | "seed"
}
```

---

## Storefront render map (already live)

| Hubsom page | Calls |
| --- | --- |
| `/` landing | `listPromotions({ placement: "landing" })` |
| `/marketplace` | `placement: "marketplace"` |
| `/categories` + `/categories/[slug]` | `placement: "category"` (+ slug filter) |
| `/products/[id]` | `placement: "product"` (+ `productId` + category) |

UI: `src/components/promotions/PromoSpace.tsx`

---

## Prompt for HubsomAdmin agent

```text
Build promotions management in https://github.com/felixamay/hubsomadmin

Connect to Hubsom storefront APIs documented in:
https://github.com/felixamay/hubsom/blob/cursor/hubsom-live-commerce-8a7a/docs/ADMIN_PROMOTIONS.md

Requirements:
1) CRUD promotions via Hubsom GET/POST/PUT/DELETE /api/admin/promotions
2) Use GET /api/admin/catalog for placement, category, and product pickers
3) Admin must select one or more placements: landing, marketplace, category, product
4) When category is selected, optional multi-select categorySlugs
5) When product is selected, optional multi-select productIds
6) Auth with HUBSOM_ADMIN_API_KEY → header X-Hubsom-Admin-Key
7) Env: HUBSOM_API_BASE_URL + HUBSOM_ADMIN_API_KEY

After save, promotions must appear on the Hubsom surfaces matching the selected placements.
```

---

## Hubsom files

| Path | Role |
| --- | --- |
| `src/types/promotions.ts` | Shared types |
| `src/lib/data/promotions.ts` | Persistence + filtering |
| `src/app/api/admin/promotions/route.ts` | Admin CRUD |
| `src/app/api/admin/catalog/route.ts` | Pickers |
| `src/app/api/promotions/route.ts` | Public feed |
| `src/lib/admin-auth.ts` | API key check |
| `src/components/promotions/PromoSpace.tsx` | Storefront UI |

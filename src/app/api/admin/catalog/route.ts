import { NextResponse } from "next/server";
import { isAdminAuthorized } from "@/lib/admin-auth";
import { CATEGORIES } from "@/lib/categories";
import { listProducts } from "@/lib/data/products";

/**
 * Catalog helpers for HubsomAdmin promotion targeting pickers.
 */
export async function GET(request: Request) {
  if (!isAdminAuthorized(request)) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const products = await listProducts();
  return NextResponse.json({
    placements: [
      {
        id: "landing",
        label: "Landing page",
        description: "Home / landing promotion rail",
      },
      {
        id: "marketplace",
        label: "Marketplace / products",
        description: "Buy Now marketplace listing",
      },
      {
        id: "category",
        label: "Category pages",
        description: "Optionally target specific category slugs",
      },
      {
        id: "product",
        label: "Product pages",
        description: "Optionally target specific product ids",
      },
    ],
    categories: CATEGORIES.map((c) => ({
      slug: c.slug,
      name: c.name,
      description: c.description,
    })),
    products: products.map((p) => ({
      id: p.id,
      slug: p.slug,
      name: p.name,
      category: p.category,
      image: p.images[0],
      priceGhs: p.priceGhs,
    })),
  });
}

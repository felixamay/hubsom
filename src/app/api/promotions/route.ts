import { NextResponse } from "next/server";
import { listPromotions } from "@/lib/data/promotions";
import type { PromoPlacement } from "@/types/promotions";

/**
 * Public storefront promotions feed.
 * Query: placement=landing|marketplace|category|product
 *        category=<slug>  productId=<id>  limit=<n>
 */
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const placementRaw = searchParams.get("placement") ?? undefined;
  const category = searchParams.get("category") ?? undefined;
  const productId = searchParams.get("productId") ?? undefined;
  const limitRaw = searchParams.get("limit");
  const limit = limitRaw ? Number(limitRaw) : undefined;

  const placement = placementRaw as PromoPlacement | "home" | undefined;

  const promotions = await listPromotions({
    placement,
    categorySlug: category ?? undefined,
    productId: productId ?? undefined,
    limit: Number.isFinite(limit) ? limit : undefined,
  });

  return NextResponse.json({
    promotions,
    meta: {
      placement: placement ?? null,
      category: category ?? null,
      productId: productId ?? null,
      count: promotions.length,
      source: "hubsom",
    },
  });
}

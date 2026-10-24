import { NextResponse } from "next/server";
import { isAdminAuthorized } from "@/lib/admin-auth";
import {
  deletePromotion,
  getPromotion,
  listAllPromotionsAdmin,
  replaceAllPromotionsFromAdmin,
  upsertPromotionFromAdmin,
} from "@/lib/data/promotions";
import type { AdminPromotionInput } from "@/types/promotions";

function unauthorized() {
  return NextResponse.json(
    { error: "Admin API key required (X-Hubsom-Admin-Key or Bearer)" },
    { status: 401 },
  );
}

/** List all promotions for HubsomAdmin (includes inactive). */
export async function GET(request: Request) {
  if (!isAdminAuthorized(request)) return unauthorized();
  const promotions = await listAllPromotionsAdmin();
  return NextResponse.json({ promotions });
}

/**
 * Create or replace promotions from HubsomAdmin.
 * - Body { promotion: AdminPromotionInput } → upsert one
 * - Body { promotions: AdminPromotionInput[] } → replace all
 */
export async function POST(request: Request) {
  if (!isAdminAuthorized(request)) return unauthorized();

  try {
    const body = (await request.json()) as {
      promotion?: AdminPromotionInput;
      promotions?: AdminPromotionInput[];
      replaceAll?: boolean;
    };

    if (Array.isArray(body.promotions) && body.replaceAll !== false) {
      // Default: if `promotions` array provided without single `promotion`, replace all
      if (!body.promotion) {
        const promotions = await replaceAllPromotionsFromAdmin(body.promotions);
        return NextResponse.json({ promotions, replaced: true });
      }
    }

    if (body.promotion) {
      const promotion = await upsertPromotionFromAdmin(body.promotion);
      return NextResponse.json({ promotion });
    }

    if (Array.isArray(body.promotions)) {
      const promotions = [];
      for (const item of body.promotions) {
        promotions.push(await upsertPromotionFromAdmin(item));
      }
      return NextResponse.json({ promotions, replaced: false });
    }

    return NextResponse.json(
      { error: "Provide promotion or promotions[]" },
      { status: 400 },
    );
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error ? error.message : "Could not save promotions",
      },
      { status: 400 },
    );
  }
}

/** Update one promotion (id in body or ?id=). */
export async function PUT(request: Request) {
  if (!isAdminAuthorized(request)) return unauthorized();
  try {
    const { searchParams } = new URL(request.url);
    const body = (await request.json()) as AdminPromotionInput;
    const id = searchParams.get("id") || body.id;
    if (!id) {
      return NextResponse.json({ error: "id required" }, { status: 400 });
    }
    const existing = await getPromotion(id);
    if (!existing) {
      return NextResponse.json({ error: "Promotion not found" }, { status: 404 });
    }
    const promotion = await upsertPromotionFromAdmin({ ...body, id });
    return NextResponse.json({ promotion });
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error ? error.message : "Could not update promotion",
      },
      { status: 400 },
    );
  }
}

/** Delete one promotion ?id= */
export async function DELETE(request: Request) {
  if (!isAdminAuthorized(request)) return unauthorized();
  const { searchParams } = new URL(request.url);
  const id = searchParams.get("id");
  if (!id) {
    return NextResponse.json({ error: "id required" }, { status: 400 });
  }
  const ok = await deletePromotion(id);
  if (!ok) {
    return NextResponse.json({ error: "Promotion not found" }, { status: 404 });
  }
  return NextResponse.json({ ok: true, id });
}

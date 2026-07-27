import { NextResponse } from "next/server";
import {
  createProduct,
  getFlashSaleProducts,
  listProducts,
} from "@/lib/data/products";
import { ensureDefaultSeller } from "@/lib/data/sellers";
import type { ProductCategory } from "@/types";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const category = searchParams.get("category");
  const sellerId = searchParams.get("sellerId");
  const flash = searchParams.get("flash");

  let items = await listProducts();
  if (category) items = items.filter((p) => p.category === category);
  if (sellerId) items = items.filter((p) => p.sellerId === sellerId);
  if (flash === "1") items = await getFlashSaleProducts();

  return NextResponse.json({ products: items, total: items.length });
}

export async function POST(request: Request) {
  const body = (await request.json()) as {
    name?: string;
    description?: string;
    category?: ProductCategory;
    priceGhs?: number;
    compareAtGhs?: number;
    stock?: number;
    sellerId?: string;
    images?: string[];
    tags?: string[];
    flashSale?: {
      endsAt: string;
      discountPct: number;
    };
  };

  if (!body.name?.trim()) {
    return NextResponse.json({ error: "name required" }, { status: 400 });
  }
  if (!body.category) {
    return NextResponse.json({ error: "category required" }, { status: 400 });
  }
  if (body.priceGhs == null || Number(body.priceGhs) < 0) {
    return NextResponse.json({ error: "priceGhs required" }, { status: 400 });
  }

  const seller = body.sellerId
    ? { id: body.sellerId }
    : await ensureDefaultSeller();

  const product = await createProduct({
    name: body.name,
    description: body.description,
    category: body.category,
    priceGhs: Number(body.priceGhs),
    compareAtGhs: body.compareAtGhs,
    stock: body.stock ?? 0,
    sellerId: seller.id,
    images: body.images,
    tags: body.tags,
    flashSale: body.flashSale,
  });

  return NextResponse.json({ product }, { status: 201 });
}

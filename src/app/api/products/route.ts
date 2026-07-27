import { NextResponse } from "next/server";
import { PRODUCTS } from "@/lib/data/products";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const category = searchParams.get("category");
  const sellerId = searchParams.get("sellerId");
  const flash = searchParams.get("flash");

  let items = PRODUCTS;
  if (category) items = items.filter((p) => p.category === category);
  if (sellerId) items = items.filter((p) => p.sellerId === sellerId);
  if (flash === "1") items = items.filter((p) => Boolean(p.flashSale));

  return NextResponse.json({ products: items, total: items.length });
}

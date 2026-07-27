import { NextResponse } from "next/server";
import { getProduct } from "@/lib/data/products";

const stockOverrides = new Map<string, number>();

export async function POST(request: Request) {
  const body = (await request.json()) as {
    productId?: string;
    delta?: number;
    streamId?: string;
  };

  if (!body.productId) {
    return NextResponse.json({ error: "productId required" }, { status: 400 });
  }

  const product = getProduct(body.productId);
  if (!product) {
    return NextResponse.json({ error: "Product not found" }, { status: 404 });
  }

  const base = stockOverrides.get(body.productId) ?? product.stock;
  const next = Math.max(0, base + (body.delta ?? -1));
  stockOverrides.set(body.productId, next);

  return NextResponse.json({
    productId: body.productId,
    streamId: body.streamId,
    stock: next,
    syncedAt: new Date().toISOString(),
    realtime: true,
  });
}

export async function GET(request: Request) {
  const productId = new URL(request.url).searchParams.get("productId");
  if (!productId) {
    return NextResponse.json({ error: "productId required" }, { status: 400 });
  }
  const product = getProduct(productId);
  if (!product) {
    return NextResponse.json({ error: "Product not found" }, { status: 404 });
  }
  return NextResponse.json({
    productId,
    stock: stockOverrides.get(productId) ?? product.stock,
  });
}

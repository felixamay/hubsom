import { NextResponse } from "next/server";
import { adjustProductStock, getProduct } from "@/lib/data/products";

export async function POST(request: Request) {
  const body = (await request.json()) as {
    productId?: string;
    delta?: number;
    streamId?: string;
  };

  if (!body.productId) {
    return NextResponse.json({ error: "productId required" }, { status: 400 });
  }

  const product = await adjustProductStock(
    body.productId,
    body.delta ?? -1,
  );
  if (!product) {
    return NextResponse.json({ error: "Product not found" }, { status: 404 });
  }

  return NextResponse.json({
    productId: body.productId,
    streamId: body.streamId,
    stock: product.stock,
    syncedAt: new Date().toISOString(),
    realtime: true,
  });
}

export async function GET(request: Request) {
  const productId = new URL(request.url).searchParams.get("productId");
  if (!productId) {
    return NextResponse.json({ error: "productId required" }, { status: 400 });
  }
  const product = await getProduct(productId);
  if (!product) {
    return NextResponse.json({ error: "Product not found" }, { status: 404 });
  }
  return NextResponse.json({
    productId,
    stock: product.stock,
  });
}

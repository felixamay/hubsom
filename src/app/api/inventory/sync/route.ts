import { NextResponse } from "next/server";
import { auth } from "@/auth";
import {
  adjustProductStock,
  getProduct,
  InsufficientStockError,
} from "@/lib/data/products";
import { getSeller } from "@/lib/data/sellers";
import { getUserById } from "@/lib/data/users";

export async function POST(request: Request) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const body = (await request.json()) as {
    productId?: string;
    delta?: number;
    streamId?: string;
  };

  if (!body.productId) {
    return NextResponse.json({ error: "productId required" }, { status: 400 });
  }

  const delta = body.delta ?? -1;
  if (!Number.isInteger(delta) || !Number.isFinite(delta)) {
    return NextResponse.json({ error: "delta must be an integer" }, { status: 400 });
  }

  const product = await getProduct(body.productId);
  if (!product) {
    return NextResponse.json({ error: "Product not found" }, { status: 404 });
  }

  const [user, seller] = await Promise.all([
    getUserById(session.user.id),
    getSeller(product.sellerId),
  ]);
  const owns = Boolean(
    seller &&
      (seller.ownerUserId === session.user.id || user?.sellerId === seller.id),
  );
  if (!owns) {
    return NextResponse.json(
      { error: "Only the seller can sync this product's inventory" },
      { status: 403 },
    );
  }

  try {
    const updated = await adjustProductStock(body.productId, delta);
    if (!updated) {
      return NextResponse.json({ error: "Product not found" }, { status: 404 });
    }

    return NextResponse.json({
      productId: body.productId,
      streamId: body.streamId,
      stock: updated.stock,
      syncedAt: new Date().toISOString(),
      realtime: true,
    });
  } catch (error) {
    if (error instanceof InsufficientStockError) {
      return NextResponse.json(
        { error: "Insufficient stock" },
        { status: 409 },
      );
    }
    throw error;
  }
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

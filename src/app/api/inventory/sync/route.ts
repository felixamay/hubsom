import { NextResponse } from "next/server";
import { auth } from "@/auth";
import { parseStockDelta, userOwnsProduct } from "@/lib/inventory-auth";
import { adjustProductStock, getProduct } from "@/lib/data/products";
import { getSeller } from "@/lib/data/sellers";
import { getUserById } from "@/lib/data/users";

export async function POST(request: Request) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const body = (await request.json()) as {
    productId?: string;
    delta?: unknown;
    streamId?: string;
  };

  if (!body.productId) {
    return NextResponse.json({ error: "productId required" }, { status: 400 });
  }

  const delta = parseStockDelta(body.delta);
  if (delta === undefined) {
    return NextResponse.json(
      { error: "delta must be an integer" },
      { status: 400 },
    );
  }

  const product = await getProduct(body.productId);
  if (!product) {
    return NextResponse.json({ error: "Product not found" }, { status: 404 });
  }

  const [user, seller] = await Promise.all([
    getUserById(session.user.id),
    getSeller(product.sellerId),
  ]);

  const owns = userOwnsProduct({
    userId: session.user.id,
    userSellerId: user?.sellerId ?? session.user.sellerId,
    productSellerId: product.sellerId,
    sellerOwnerUserId: seller?.ownerUserId,
  });
  if (!owns) {
    return NextResponse.json(
      { error: "Only the seller can sync this listing's stock" },
      { status: 403 },
    );
  }

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

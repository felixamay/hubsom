import { NextResponse } from "next/server";
import { auth } from "@/auth";
import {
  createProduct,
  getFlashSaleProducts,
  listProducts,
} from "@/lib/data/products";
import { ensureSellerForUser } from "@/lib/data/sellers";
import { getUserById, updateUserProfile } from "@/lib/data/users";
import type { ProductCategory } from "@/types";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const category = searchParams.get("category");
  const sellerId = searchParams.get("sellerId");
  const flash = searchParams.get("flash");
  const mine = searchParams.get("mine");

  let items = await listProducts();

  if (mine === "1") {
    const session = await auth();
    if (!session?.user?.id) {
      return NextResponse.json({ products: [], total: 0 });
    }
    const user = await getUserById(session.user.id);
    const seller = user
      ? await ensureSellerForUser({
          userId: user.id,
          name: user.name,
          city: user.city,
          region: user.region,
          bio: user.bio,
          avatar: user.image,
        })
      : null;
    items = seller
      ? items.filter((p) => p.sellerId === seller.id)
      : [];
  }

  if (category) items = items.filter((p) => p.category === category);
  if (sellerId) items = items.filter((p) => p.sellerId === sellerId);
  if (flash === "1") items = await getFlashSaleProducts();

  return NextResponse.json({ products: items, total: items.length });
}

export async function POST(request: Request) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const body = (await request.json()) as {
    name?: string;
    description?: string;
    category?: ProductCategory;
    priceGhs?: number;
    compareAtGhs?: number;
    stock?: number;
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

  const user = await getUserById(session.user.id);
  if (!user) {
    return NextResponse.json({ error: "User not found" }, { status: 404 });
  }

  const seller = await ensureSellerForUser({
    userId: user.id,
    name: user.name,
    city: user.city,
    region: user.region,
    bio: user.bio,
    avatar: user.image,
  });

  if (!user.sellerId || user.role === "buyer") {
    await updateUserProfile(user.id, {
      sellerId: seller.id,
      role: user.role === "seller" ? "seller" : "both",
    });
  }

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

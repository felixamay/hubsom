import { NextResponse } from "next/server";
import { auth } from "@/auth";
import { createLiveStream, listAllStreams } from "@/lib/data/stream-registry";
import { getProduct } from "@/lib/data/products";
import { ensureSellerForUser, getSeller } from "@/lib/data/sellers";
import { getUserById, updateUserProfile } from "@/lib/data/users";

export async function GET() {
  const streams = await Promise.all(
    (await listAllStreams()).map(async (stream) => ({
      ...stream,
      seller: (await getSeller(stream.sellerId)) ?? null,
    })),
  );
  return NextResponse.json({ streams });
}

export async function POST(request: Request) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const body = (await request.json()) as {
    title?: string;
    description?: string;
    productIds?: string[];
    pinnedProductId?: string;
    auctionProductId?: string | null;
    multiHost?: boolean;
    enableRecording?: boolean;
    startingBidGhs?: number;
  };

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

  if (!user.sellerId) {
    await updateUserProfile(user.id, {
      sellerId: seller.id,
      role: user.role === "buyer" ? "both" : user.role,
    });
  }

  const productIds: string[] = [];
  for (const id of body.productIds ?? []) {
    const product = await getProduct(id);
    if (product && product.sellerId === seller.id) productIds.push(id);
  }

  if (!productIds.length) {
    return NextResponse.json(
      { error: "Select at least one of your products for the show" },
      { status: 400 },
    );
  }

  const stream = await createLiveStream({
    title: body.title?.trim() || "Hubsom Live Show",
    description: body.description,
    sellerId: seller.id,
    productIds,
    pinnedProductId: body.pinnedProductId,
    auctionProductId: body.auctionProductId || undefined,
    multiHost: body.multiHost,
    enableRecording: body.enableRecording,
    startingBidGhs: body.startingBidGhs,
  });

  return NextResponse.json({ stream }, { status: 201 });
}

import { NextResponse } from "next/server";
import { auth } from "@/auth";
import {
  blockSeller,
  isSellerBlocked,
  messageSeller,
  reportSeller,
  reviewSeller,
  tipSeller,
  unblockSeller,
} from "@/lib/data/seller-social";
import { getSeller } from "@/lib/data/sellers";

export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }
  const { id } = await context.params;
  const seller = await getSeller(id);
  if (!seller) {
    return NextResponse.json({ error: "Seller not found" }, { status: 404 });
  }
  const blocked = await isSellerBlocked(session.user.id, id);
  return NextResponse.json({ blocked, sellerId: id });
}

export async function POST(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { id } = await context.params;
  const seller = await getSeller(id);
  if (!seller) {
    return NextResponse.json({ error: "Seller not found" }, { status: 404 });
  }

  const body = (await request.json()) as {
    action?: string;
    amountGhs?: number;
    reason?: string;
    details?: string;
    text?: string;
    rating?: number;
    streamId?: string;
  };

  const userName = session.user.name || "Hubsom user";
  const userId = session.user.id;

  try {
    switch (body.action) {
      case "block":
        return NextResponse.json(await blockSeller(userId, id));
      case "unblock":
        return NextResponse.json(await unblockSeller(userId, id));
      case "report":
        return NextResponse.json(
          await reportSeller({
            sellerId: id,
            userId,
            reason: body.reason || "Inappropriate",
            details: body.details,
            streamId: body.streamId,
          }),
        );
      case "tip":
        return NextResponse.json(
          await tipSeller({
            sellerId: id,
            userId,
            userName,
            amountGhs: Number(body.amountGhs),
            streamId: body.streamId,
          }),
        );
      case "review":
        return NextResponse.json(
          await reviewSeller({
            sellerId: id,
            userId,
            userName,
            rating: Number(body.rating) || 5,
            text: String(body.text ?? ""),
          }),
        );
      case "message":
        return NextResponse.json(
          await messageSeller({
            sellerId: id,
            fromUserId: userId,
            fromUserName: userName,
            text: String(body.text ?? ""),
          }),
        );
      default:
        return NextResponse.json({ error: "Unknown action" }, { status: 400 });
    }
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Request failed" },
      { status: 400 },
    );
  }
}

import { NextResponse } from "next/server";
import { auth } from "@/auth";
import {
  followSeller,
  isFollowingSeller,
  unfollowSeller,
} from "@/lib/data/follows";
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

  const following = await isFollowingSeller(session.user.id, id);
  return NextResponse.json({
    following,
    followers: seller.followers,
    isOwnStore:
      seller.ownerUserId === session.user.id ||
      session.user.sellerId === seller.id,
  });
}

export async function POST(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { id } = await context.params;
  try {
    const result = await followSeller(session.user.id, id);
    return NextResponse.json({
      following: result.following,
      followers: result.seller.followers,
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Could not follow" },
      { status: 400 },
    );
  }
}

export async function DELETE(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { id } = await context.params;
  try {
    const result = await unfollowSeller(session.user.id, id);
    return NextResponse.json({
      following: result.following,
      followers: result.seller.followers,
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Could not unfollow" },
      { status: 400 },
    );
  }
}

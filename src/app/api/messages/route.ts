import { NextResponse } from "next/server";
import { auth } from "@/auth";
import {
  countUnreadForUser,
  listConversationsForUser,
  listMessageableUsers,
  resolvePeerUserIdForSeller,
  sendDirectMessage,
} from "@/lib/data/messages";

export async function GET(request: Request) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { searchParams } = new URL(request.url);
  const sellerId = searchParams.get("sellerId");
  if (sellerId) {
    const peerUserId = await resolvePeerUserIdForSeller(sellerId);
    if (!peerUserId) {
      return NextResponse.json(
        { error: "This seller can’t receive messages yet" },
        { status: 404 },
      );
    }
    if (peerUserId === session.user.id) {
      return NextResponse.json(
        { error: "That’s your own store" },
        { status: 400 },
      );
    }
    return NextResponse.json({ peerUserId });
  }

  const userId = session.user.id;
  const [conversations, people, unreadCount] = await Promise.all([
    listConversationsForUser(userId),
    listMessageableUsers(userId),
    countUnreadForUser(userId),
  ]);

  return NextResponse.json({ conversations, people, unreadCount });
}

export async function POST(request: Request) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const body = (await request.json()) as {
    toUserId?: string;
    sellerId?: string;
    text?: string;
  };

  let toUserId = body.toUserId?.trim();
  if (!toUserId && body.sellerId) {
    toUserId =
      (await resolvePeerUserIdForSeller(body.sellerId)) ?? undefined;
    if (!toUserId) {
      return NextResponse.json(
        { error: "This seller can’t receive messages yet" },
        { status: 400 },
      );
    }
  }

  if (!toUserId) {
    return NextResponse.json({ error: "Recipient required" }, { status: 400 });
  }

  try {
    const message = await sendDirectMessage({
      fromUserId: session.user.id,
      toUserId,
      text: String(body.text ?? ""),
    });
    return NextResponse.json({ message, peerUserId: toUserId });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Could not send" },
      { status: 400 },
    );
  }
}

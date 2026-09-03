import { NextResponse } from "next/server";
import { auth } from "@/auth";
import {
  listThread,
  markThreadRead,
  sendDirectMessage,
} from "@/lib/data/messages";

export async function GET(
  _request: Request,
  context: { params: Promise<{ userId: string }> },
) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { userId: peerUserId } = await context.params;
  const thread = await listThread(session.user.id, peerUserId);
  if (!thread) {
    return NextResponse.json({ error: "User not found" }, { status: 404 });
  }

  await markThreadRead(session.user.id, peerUserId);
  return NextResponse.json(thread);
}

export async function POST(
  request: Request,
  context: { params: Promise<{ userId: string }> },
) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { userId: peerUserId } = await context.params;
  const body = (await request.json()) as { text?: string };

  try {
    const message = await sendDirectMessage({
      fromUserId: session.user.id,
      toUserId: peerUserId,
      text: String(body.text ?? ""),
    });
    return NextResponse.json({ message });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Could not send" },
      { status: 400 },
    );
  }
}

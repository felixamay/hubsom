import { NextResponse } from "next/server";
import { auth } from "@/auth";
import { appendChatMessage, listChatMessages } from "@/lib/data/chat";
import { getUserById } from "@/lib/data/users";
import { getStreamById } from "@/lib/data/stream-registry";

export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  if (!(await getStreamById(id))) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }
  const messages = await listChatMessages(id);
  return NextResponse.json({ messages });
}

export async function POST(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  if (!(await getStreamById(id))) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }

  const session = await auth();
  const body = (await request.json()) as {
    text?: string;
    displayName?: string;
    userId?: string;
  };

  const text = body.text?.trim();
  if (!text) {
    return NextResponse.json({ error: "text required" }, { status: 400 });
  }

  const blocked = /\b(scam|hate|kill|xxx)\b/i.test(text) || text.length > 280;
  if (blocked) {
    return NextResponse.json(
      { error: "Message blocked by moderation", moderated: true },
      { status: 422 },
    );
  }

  const dbUser = session?.user?.id
    ? await getUserById(session.user.id)
    : undefined;

  const message = await appendChatMessage({
    id: `m-${Date.now().toString(36)}`,
    streamId: id,
    userId: dbUser?.id ?? body.userId ?? "guest",
    displayName:
      dbUser?.name ||
      session?.user?.name ||
      body.displayName?.trim() ||
      "Guest",
    text,
    createdAt: new Date().toISOString(),
  });

  return NextResponse.json({ message });
}

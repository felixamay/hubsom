import { NextResponse } from "next/server";
import { SEED_CHAT } from "@/lib/data/streams";
import { getStreamById } from "@/lib/data/stream-registry";

const runtimeChat = new Map<string, Array<(typeof SEED_CHAT)[number]>>();

export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  if (!(await getStreamById(id))) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }
  const seeded = SEED_CHAT.filter((m) => m.streamId === id);
  const extra = runtimeChat.get(id) ?? [];
  return NextResponse.json({ messages: [...seeded, ...extra] });
}

export async function POST(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  if (!(await getStreamById(id))) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }

  const body = (await request.json()) as {
    text?: string;
    displayName?: string;
    userId?: string;
  };

  const text = body.text?.trim();
  if (!text) {
    return NextResponse.json({ error: "text required" }, { status: 400 });
  }

  const blocked =
    /\b(scam|hate|kill|xxx)\b/i.test(text) || text.length > 280;
  if (blocked) {
    return NextResponse.json(
      { error: "Message blocked by AI moderation", moderated: true },
      { status: 422 },
    );
  }

  const message = {
    id: `m-${Date.now()}`,
    streamId: id,
    userId: body.userId ?? "guest",
    displayName: body.displayName?.trim() || "Guest",
    text,
    createdAt: new Date().toISOString(),
  };

  const list = runtimeChat.get(id) ?? [];
  list.push(message);
  runtimeChat.set(id, list.slice(-100));

  return NextResponse.json({ message });
}

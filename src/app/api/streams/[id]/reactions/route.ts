import { NextResponse } from "next/server";
import { getStream } from "@/lib/data/streams";

export async function POST(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  if (!getStream(id)) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }

  const body = (await request.json()) as { emoji?: string; x?: number };
  const emoji = body.emoji || "❤️";
  const x = typeof body.x === "number" ? body.x : Math.random();

  return NextResponse.json({
    reaction: {
      id: `r-${Date.now()}`,
      streamId: id,
      emoji,
      x,
      createdAt: Date.now(),
    },
  });
}

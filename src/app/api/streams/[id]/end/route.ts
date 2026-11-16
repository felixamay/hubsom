import { NextResponse } from "next/server";
import { auth } from "@/auth";
import { endLiveStream, getStreamById } from "@/lib/data/stream-registry";
import { isStreamHost } from "@/lib/live/host-auth";

export async function POST(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { id } = await context.params;
  const stream = await getStreamById(id);
  if (!stream) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }

  if (!(await isStreamHost(session.user.id, stream))) {
    return NextResponse.json(
      { error: "Only the host can end this live show" },
      { status: 403 },
    );
  }

  const ended = await endLiveStream(id);
  if (!ended) {
    return NextResponse.json({ error: "Could not end show" }, { status: 500 });
  }

  return NextResponse.json({ stream: ended, ok: true });
}

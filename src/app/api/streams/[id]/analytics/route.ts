import { NextResponse } from "next/server";
import { getStreamAnalytics } from "@/lib/data/analytics";
import { getStreamById } from "@/lib/data/stream-registry";

export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  if (!(await getStreamById(id))) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }
  const analytics = await getStreamAnalytics(id);
  return NextResponse.json(analytics);
}

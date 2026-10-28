import { NextResponse } from "next/server";
import { auth } from "@/auth";
import { getProduct } from "@/lib/data/products";
import { getSeller } from "@/lib/data/sellers";
import { getStreamById, patchStream } from "@/lib/data/stream-registry";
import { getUserById } from "@/lib/data/users";
import {
  isStreamHost,
  sanitizeHostStreamPatch,
} from "@/lib/live/host-stream";

export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const stream = await getStreamById(id);
  if (!stream) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }

  const products = (
    await Promise.all(stream.productIds.map((pid) => getProduct(pid)))
  ).filter(Boolean);

  return NextResponse.json({
    stream,
    seller: (await getSeller(stream.sellerId)) ?? null,
    products,
    capabilities: {
      multiHost: stream.isMultiHost,
      recording: stream.replayAvailable,
      auctions: Boolean(stream.auction),
      liveCart: true,
      reactions: true,
      chat: true,
      inventorySync: true,
    },
  });
}

export async function PATCH(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { id } = await context.params;
  const current = await getStreamById(id);
  if (!current) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }

  const [user, seller] = await Promise.all([
    getUserById(session.user.id),
    getSeller(current.sellerId),
  ]);

  if (
    !isStreamHost({
      userId: session.user.id,
      userSellerId: user?.sellerId ?? session.user.sellerId,
      seller,
    })
  ) {
    return NextResponse.json(
      { error: "Only the host can update this live show" },
      { status: 403 },
    );
  }

  let body: Record<string, unknown> = {};
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    body = {};
  }

  const { patch, error } = sanitizeHostStreamPatch(body);
  if (error) {
    return NextResponse.json({ error }, { status: 400 });
  }

  const stream = await patchStream(id, patch);
  if (!stream) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }
  return NextResponse.json({ stream });
}

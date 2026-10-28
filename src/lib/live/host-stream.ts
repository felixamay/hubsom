import type { LiveStream, Seller } from "@/types";

/** True when the signed-in user owns the store that is hosting this show. */
export function isStreamHost(args: {
  userId?: string | null;
  userSellerId?: string | null;
  seller?: Pick<Seller, "id" | "ownerUserId"> | null;
}): boolean {
  const userId = args.userId?.trim();
  const seller = args.seller;
  if (!userId || !seller) return false;
  return (
    seller.ownerUserId === userId ||
    args.userSellerId === seller.id
  );
}

/**
 * Host PATCH may pin a product or mark recording/replay.
 * Status, auction, sellerId, and other fields are ignored so a viewer
 * cannot end the show or rewrite the lot through this endpoint.
 */
export function sanitizeHostStreamPatch(
  body: Record<string, unknown>,
): { patch: Partial<LiveStream>; error?: string } {
  const patch: Partial<LiveStream> = {};

  if (body.pinnedProductId !== undefined) {
    if (
      typeof body.pinnedProductId !== "string" ||
      !body.pinnedProductId.trim()
    ) {
      return { patch: {}, error: "pinnedProductId required" };
    }
    patch.pinnedProductId = body.pinnedProductId.trim();
  }

  if (body.recording === true) {
    patch.replayAvailable = true;
  }

  if (Object.keys(patch).length === 0) {
    return { patch: {}, error: "No allowed host fields in patch" };
  }

  return { patch };
}

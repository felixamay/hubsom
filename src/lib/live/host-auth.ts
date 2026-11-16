import { getSeller } from "@/lib/data/sellers";
import { getUserById } from "@/lib/data/users";
import type { LiveStream } from "@/types";

export async function isStreamHost(
  userId: string | undefined,
  stream: LiveStream,
): Promise<boolean> {
  if (!userId) return false;
  const [user, seller] = await Promise.all([
    getUserById(userId),
    getSeller(stream.sellerId),
  ]);
  return Boolean(
    seller &&
      (seller.ownerUserId === userId ||
        user?.sellerId === seller.id),
  );
}

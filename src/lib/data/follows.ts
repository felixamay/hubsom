import { getSeller, updateSeller } from "@/lib/data/sellers";
import {
  getUserById,
  listUsers,
  toPublicUser,
  updateUserProfile,
} from "@/lib/data/users";
import type { Seller } from "@/types";
import type { HubsomUser, PublicUser } from "@/types/auth";

export function isOwnSellerStore(
  user: Pick<HubsomUser, "id" | "sellerId"> | null | undefined,
  seller: Pick<Seller, "id" | "ownerUserId"> | null | undefined,
): boolean {
  if (!user || !seller) return false;
  if (user.sellerId && user.sellerId === seller.id) return true;
  if (seller.ownerUserId && seller.ownerUserId === user.id) return true;
  return false;
}

export async function isFollowingSeller(
  userId: string,
  sellerId: string,
): Promise<boolean> {
  const user = await getUserById(userId);
  return Boolean(user?.followingSellerIds?.includes(sellerId));
}

export async function listFollowedSellers(userId: string): Promise<Seller[]> {
  const user = await getUserById(userId);
  if (!user?.followingSellerIds?.length) return [];
  const sellers = await Promise.all(
    user.followingSellerIds.map((id) => getSeller(id)),
  );
  return sellers.filter(
    (s): s is Seller => Boolean(s) && !isOwnSellerStore(user, s),
  );
}

/** Users who follow this seller’s store. */
export async function listFollowersForSeller(
  sellerId: string,
): Promise<PublicUser[]> {
  const seller = await getSeller(sellerId);
  const users = await listUsers();
  return users
    .filter((u) => u.followingSellerIds?.includes(sellerId))
    .filter((u) => !isOwnSellerStore(u, seller))
    .map((u) => toPublicUser(u));
}

export async function getFollowCounts(userId: string): Promise<{
  followingCount: number;
  followersCount: number;
  sellerId?: string;
}> {
  const user = await getUserById(userId);
  if (!user) return { followingCount: 0, followersCount: 0 };

  const followingCount = (await listFollowedSellers(userId)).length;
  let followersCount = 0;
  const sellerId = user.sellerId;
  if (sellerId) {
    const followers = await listFollowersForSeller(sellerId);
    followersCount = followers.filter((f) => f.id !== userId).length;
  }

  return { followingCount, followersCount, sellerId };
}

export async function followSeller(
  userId: string,
  sellerId: string,
): Promise<{ user: HubsomUser; seller: Seller; following: true }> {
  const [user, seller] = await Promise.all([
    getUserById(userId),
    getSeller(sellerId),
  ]);
  if (!user) throw new Error("User not found");
  if (!seller) throw new Error("Seller not found");
  if (isOwnSellerStore(user, seller)) {
    throw new Error("You can’t follow yourself");
  }

  const followingSellerIds = Array.from(
    new Set([...(user.followingSellerIds ?? []), sellerId]),
  );
  if (followingSellerIds.length === (user.followingSellerIds?.length ?? 0)) {
    return { user, seller, following: true };
  }

  const updatedUser = await updateUserProfile(userId, { followingSellerIds });
  const updatedSeller = await updateSeller(sellerId, {
    followers: Math.max(0, (seller.followers ?? 0) + 1),
  });
  if (!updatedUser || !updatedSeller) {
    throw new Error("Could not follow seller");
  }
  return { user: updatedUser, seller: updatedSeller, following: true };
}

export async function unfollowSeller(
  userId: string,
  sellerId: string,
): Promise<{ user: HubsomUser; seller: Seller; following: false }> {
  const [user, seller] = await Promise.all([
    getUserById(userId),
    getSeller(sellerId),
  ]);
  if (!user) throw new Error("User not found");
  if (!seller) throw new Error("Seller not found");

  const before = user.followingSellerIds ?? [];
  if (!before.includes(sellerId)) {
    return { user, seller, following: false };
  }

  const followingSellerIds = before.filter((id) => id !== sellerId);
  const updatedUser = await updateUserProfile(userId, { followingSellerIds });
  const updatedSeller = await updateSeller(sellerId, {
    followers: Math.max(0, (seller.followers ?? 0) - 1),
  });
  if (!updatedUser || !updatedSeller) {
    throw new Error("Could not unfollow seller");
  }
  return { user: updatedUser, seller: updatedSeller, following: false };
}

import { getSeller, updateSeller } from "@/lib/data/sellers";
import {
  getUserById,
  listUsers,
  toPublicUser,
  updateUserProfile,
} from "@/lib/data/users";
import type { Seller } from "@/types";
import type { HubsomUser, PublicUser } from "@/types/auth";

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
  return sellers.filter((s): s is Seller => Boolean(s));
}

/** Users who follow this seller’s store. */
export async function listFollowersForSeller(
  sellerId: string,
): Promise<PublicUser[]> {
  const users = await listUsers();
  return users
    .filter((u) => u.followingSellerIds?.includes(sellerId))
    .map((u) => toPublicUser(u));
}

export async function getFollowCounts(userId: string): Promise<{
  followingCount: number;
  followersCount: number;
  sellerId?: string;
}> {
  const user = await getUserById(userId);
  if (!user) return { followingCount: 0, followersCount: 0 };

  const followingCount = user.followingSellerIds?.length ?? 0;
  let followersCount = 0;
  const sellerId = user.sellerId;
  if (sellerId) {
    const followers = await listFollowersForSeller(sellerId);
    followersCount = followers.length;
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
  if (seller.ownerUserId && seller.ownerUserId === userId) {
    throw new Error("You can’t follow your own store");
  }
  if (user.sellerId && user.sellerId === sellerId) {
    throw new Error("You can’t follow your own store");
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

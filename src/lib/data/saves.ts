import { getProduct } from "@/lib/data/products";
import { getUserById, updateUserProfile } from "@/lib/data/users";
import type { Product } from "@/types";
import type { HubsomUser } from "@/types/auth";

export async function isProductSaved(
  userId: string,
  productId: string,
): Promise<boolean> {
  const user = await getUserById(userId);
  return Boolean(user?.savedProductIds?.includes(productId));
}

export async function listSavedProducts(userId: string): Promise<Product[]> {
  const user = await getUserById(userId);
  if (!user?.savedProductIds?.length) return [];
  const products = await Promise.all(
    user.savedProductIds.map((id) => getProduct(id)),
  );
  return products.filter((p): p is Product => Boolean(p));
}

export async function saveProduct(
  userId: string,
  productId: string,
): Promise<{ user: HubsomUser; saved: true }> {
  const [user, product] = await Promise.all([
    getUserById(userId),
    getProduct(productId),
  ]);
  if (!user) throw new Error("User not found");
  if (!product) throw new Error("Product not found");

  const savedProductIds = Array.from(
    new Set([...(user.savedProductIds ?? []), productId]),
  );
  if (savedProductIds.length === (user.savedProductIds?.length ?? 0)) {
    return { user, saved: true };
  }

  const updatedUser = await updateUserProfile(userId, { savedProductIds });
  if (!updatedUser) throw new Error("Could not save product");
  return { user: updatedUser, saved: true };
}

export async function unsaveProduct(
  userId: string,
  productId: string,
): Promise<{ user: HubsomUser; saved: false }> {
  const user = await getUserById(userId);
  if (!user) throw new Error("User not found");

  const before = user.savedProductIds ?? [];
  if (!before.includes(productId)) {
    return { user, saved: false };
  }

  const savedProductIds = before.filter((id) => id !== productId);
  const updatedUser = await updateUserProfile(userId, { savedProductIds });
  if (!updatedUser) throw new Error("Could not unsave product");
  return { user: updatedUser, saved: false };
}

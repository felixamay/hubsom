import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { StorefrontEditor } from "@/components/seller/StorefrontEditor";
import { requireUser } from "@/lib/auth/session";
import { ensureSellerForUser } from "@/lib/data/sellers";
import { getUserById, updateUserProfile } from "@/lib/data/users";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Edit storefront",
  description: "Update your Hubsom store name, profile photo, and cover.",
};

export default async function EditStorefrontPage() {
  const session = await requireUser("/seller/store");
  const user = await getUserById(session.user.id);
  if (!user) redirect("/auth/sign-in?callbackUrl=/seller/store");

  const seller = await ensureSellerForUser({
    userId: user.id,
    name: user.name,
    city: user.city,
    region: user.region,
    bio: user.bio,
    avatar: user.image,
  });

  if (user.sellerId !== seller.id) {
    await updateUserProfile(user.id, {
      sellerId: seller.id,
      role: user.role === "buyer" ? "both" : user.role,
    });
  }

  return <StorefrontEditor initialSeller={seller} />;
}

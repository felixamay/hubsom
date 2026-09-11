import { NextResponse } from "next/server";
import { auth } from "@/auth";
import { ensureSellerForUser, updateSeller } from "@/lib/data/sellers";
import { getUserById, updateUserProfile } from "@/lib/data/users";
import type { Seller } from "@/types";
import type { HubsomUser } from "@/types/auth";

async function requireOwnedStore(): Promise<
  | { error: NextResponse }
  | { user: HubsomUser; seller: Seller }
> {
  const session = await auth();
  if (!session?.user?.id) {
    return {
      error: NextResponse.json({ error: "Sign in required" }, { status: 401 }),
    };
  }
  const user = await getUserById(session.user.id);
  if (!user) {
    return {
      error: NextResponse.json({ error: "User not found" }, { status: 404 }),
    };
  }
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
  return { user, seller };
}

export async function GET() {
  const result = await requireOwnedStore();
  if ("error" in result) return result.error;
  return NextResponse.json({ seller: result.seller });
}

export async function PATCH(request: Request) {
  const result = await requireOwnedStore();
  if ("error" in result) return result.error;

  const body = (await request.json()) as {
    name?: string;
    bio?: string;
    city?: string;
    region?: string;
    avatar?: string;
    cover?: string;
  };

  if (body.name !== undefined && !body.name.trim()) {
    return NextResponse.json(
      { error: "Store name is required" },
      { status: 400 },
    );
  }

  try {
    const updated = await updateSeller(result.seller.id, {
      name: body.name,
      bio: body.bio,
      city: body.city,
      region: body.region,
      avatar: body.avatar,
      cover: body.cover,
    });
    return NextResponse.json({ seller: updated });
  } catch (error) {
    return NextResponse.json(
      {
        error: error instanceof Error ? error.message : "Could not save store",
      },
      { status: 400 },
    );
  }
}

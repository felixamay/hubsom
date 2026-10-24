import { NextResponse } from "next/server";
import { auth } from "@/auth";
import { ensureSellerForUser } from "@/lib/data/sellers";
import {
  getUserById,
  toPublicUser,
  updateUserProfile,
} from "@/lib/data/users";

export async function GET() {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const user = await getUserById(session.user.id);
  if (!user) {
    return NextResponse.json({ error: "User not found" }, { status: 404 });
  }
  return NextResponse.json({ user: toPublicUser(user) });
}

export async function PATCH(request: Request) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = (await request.json()) as {
    name?: string;
    phone?: string;
    city?: string;
    region?: string;
    bio?: string;
    image?: string;
    enableSeller?: boolean;
  };

  const current = await getUserById(session.user.id);
  if (!current) {
    return NextResponse.json({ error: "User not found" }, { status: 404 });
  }

  const name = body.name?.trim() || current.name;
  let sellerId = current.sellerId;
  let role = current.role;

  if (body.enableSeller || current.sellerId) {
    const seller = await ensureSellerForUser({
      userId: current.id,
      name,
      city: body.city?.trim() || current.city,
      region: body.region?.trim() || current.region,
      bio: body.bio?.trim() || current.bio,
      avatar: body.image?.trim() || current.image,
    });
    sellerId = seller.id;
    role = current.role === "buyer" ? "both" : current.role === "seller" ? "seller" : "both";
    if (body.enableSeller) role = role === "seller" ? "seller" : "both";
  }

  const user = await updateUserProfile(session.user.id, {
    name,
    phone: body.phone?.trim(),
    city: body.city?.trim(),
    region: body.region?.trim(),
    bio: body.bio?.trim(),
    image: body.image?.trim() || current.image,
    sellerId,
    role,
  });

  return NextResponse.json({ user: user ? toPublicUser(user) : null });
}

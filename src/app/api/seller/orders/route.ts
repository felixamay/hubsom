import { NextResponse } from "next/server";
import { auth } from "@/auth";
import { listOrdersBySeller } from "@/lib/data/orders";
import { ensureSellerForUser } from "@/lib/data/sellers";
import { getUserById } from "@/lib/data/users";

export async function GET() {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }
  const user = await getUserById(session.user.id);
  if (!user) {
    return NextResponse.json({ error: "User not found" }, { status: 404 });
  }
  const seller = await ensureSellerForUser({
    userId: user.id,
    name: user.name,
    city: user.city,
    region: user.region,
    bio: user.bio,
    avatar: user.image,
  });
  const orders = await listOrdersBySeller(seller.id);
  return NextResponse.json({ orders, sellerId: seller.id });
}

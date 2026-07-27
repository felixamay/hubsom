import { NextResponse } from "next/server";
import { auth } from "@/auth";
import {
  getOrder,
  updateOrderStatus,
  type OrderStatus,
} from "@/lib/data/orders";
import { ensureSellerForUser } from "@/lib/data/sellers";
import { getUserById } from "@/lib/data/users";

const ALLOWED: OrderStatus[] = [
  "pending_payment",
  "paid",
  "fulfilled",
  "cancelled",
];

export async function PATCH(
  request: Request,
  context: { params: Promise<{ orderId: string }> },
) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { orderId } = await context.params;
  const body = (await request.json()) as { status?: OrderStatus };
  if (!body.status || !ALLOWED.includes(body.status)) {
    return NextResponse.json({ error: "Invalid status" }, { status: 400 });
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

  const existing = await getOrder(orderId);
  if (!existing) {
    return NextResponse.json({ error: "Order not found" }, { status: 404 });
  }
  if (!existing.lines.some((l) => l.sellerId === seller.id)) {
    return NextResponse.json({ error: "Not your order" }, { status: 403 });
  }

  const order = await updateOrderStatus(orderId, body.status);
  return NextResponse.json({ order });
}

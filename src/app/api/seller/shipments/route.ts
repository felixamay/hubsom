import { NextResponse } from "next/server";
import { auth } from "@/auth";
import {
  createConsolidatedShipment,
  listShipmentsBySeller,
} from "@/lib/data/shipments";
import type { OrderShipping } from "@/lib/data/orders";
import { ensureSellerForUser } from "@/lib/data/sellers";
import { getUserById } from "@/lib/data/users";

async function resolveSeller(userId: string) {
  const user = await getUserById(userId);
  if (!user) return null;
  const seller = await ensureSellerForUser({
    userId: user.id,
    name: user.name,
    city: user.city,
    region: user.region,
    bio: user.bio,
    avatar: user.image,
  });
  return { user, seller };
}

export async function GET() {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }
  const resolved = await resolveSeller(session.user.id);
  if (!resolved) {
    return NextResponse.json({ error: "User not found" }, { status: 404 });
  }
  const shipments = await listShipmentsBySeller(resolved.seller.id);
  return NextResponse.json({ shipments });
}

export async function POST(request: Request) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const resolved = await resolveSeller(session.user.id);
  if (!resolved) {
    return NextResponse.json({ error: "User not found" }, { status: 404 });
  }

  const body = (await request.json()) as {
    orderIds?: string[];
    destination?: Partial<OrderShipping>;
    notes?: string;
  };

  try {
    const shipment = await createConsolidatedShipment({
      sellerId: resolved.seller.id,
      createdByUserId: session.user.id,
      orderIds: body.orderIds ?? [],
      destination: body.destination,
      notes: body.notes,
    });
    return NextResponse.json({ shipment });
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : "Could not create shipment",
      },
      { status: 400 },
    );
  }
}

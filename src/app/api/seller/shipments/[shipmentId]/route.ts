import { NextResponse } from "next/server";
import { auth } from "@/auth";
import type { OrderShipping } from "@/lib/data/orders";
import {
  getShipment,
  updateShipmentDestination,
  type ShipmentStatus,
} from "@/lib/data/shipments";
import { ensureSellerForUser } from "@/lib/data/sellers";
import { getUserById } from "@/lib/data/users";

export async function GET(
  _request: Request,
  context: { params: Promise<{ shipmentId: string }> },
) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { shipmentId } = await context.params;
  const shipment = await getShipment(shipmentId);
  if (!shipment) {
    return NextResponse.json({ error: "Shipment not found" }, { status: 404 });
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
  if (shipment.sellerId !== seller.id) {
    return NextResponse.json({ error: "Not your shipment" }, { status: 403 });
  }

  return NextResponse.json({ shipment });
}

export async function PATCH(
  request: Request,
  context: { params: Promise<{ shipmentId: string }> },
) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { shipmentId } = await context.params;
  const existing = await getShipment(shipmentId);
  if (!existing) {
    return NextResponse.json({ error: "Shipment not found" }, { status: 404 });
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
  if (existing.sellerId !== seller.id) {
    return NextResponse.json({ error: "Not your shipment" }, { status: 403 });
  }

  const body = (await request.json()) as {
    destination?: Partial<OrderShipping>;
    location?: {
      latitude: number;
      longitude: number;
      accuracyM?: number;
      source?: "gps" | "map-pin" | "manual" | "geocoded";
    } | null;
    notes?: string;
    status?: ShipmentStatus;
  };

  try {
    const shipment = await updateShipmentDestination(shipmentId, body);
    return NextResponse.json({ shipment });
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : "Could not update shipment",
      },
      { status: 400 },
    );
  }
}

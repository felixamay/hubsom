import { NextResponse } from "next/server";
import { auth } from "@/auth";
import { sendHubersDeliveryOffers } from "@/lib/hubers/client";
import { getShipment } from "@/lib/data/shipments";
import { ensureSellerForUser } from "@/lib/data/sellers";
import { getUserById } from "@/lib/data/users";

export async function POST(
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

  const body = (await request.json().catch(() => ({}))) as {
    preferredFeeGhs?: number;
  };

  try {
    const result = await sendHubersDeliveryOffers({
      shipment: existing,
      preferredFeeGhs: body.preferredFeeGhs,
    });
    return NextResponse.json(result);
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : "Could not send Hubers offers",
      },
      { status: 400 },
    );
  }
}

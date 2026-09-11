import { NextResponse } from "next/server";
import { auth } from "@/auth";
import {
  deleteAddress,
  getUserById,
  toPublicUser,
  upsertAddress,
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
  return NextResponse.json({ addresses: user.addresses });
}

export async function POST(request: Request) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = (await request.json()) as {
    id?: string;
    label?: string;
    line1?: string;
    line2?: string;
    city?: string;
    region?: string;
    phone?: string;
    isDefault?: boolean;
  };

  try {
    const user = await upsertAddress(session.user.id, {
      id: body.id,
      label: body.label ?? "Home",
      line1: body.line1 ?? "",
      line2: body.line2,
      city: body.city ?? "Accra",
      region: body.region ?? "Greater Accra",
      phone: body.phone,
      isDefault: body.isDefault,
    });
    return NextResponse.json({
      user: user ? toPublicUser(user) : null,
      addresses: user?.addresses ?? [],
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Could not save address" },
      { status: 400 },
    );
  }
}

export async function DELETE(request: Request) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const id = new URL(request.url).searchParams.get("id");
  if (!id) {
    return NextResponse.json({ error: "id required" }, { status: 400 });
  }
  const user = await deleteAddress(session.user.id, id);
  return NextResponse.json({
    user: user ? toPublicUser(user) : null,
    addresses: user?.addresses ?? [],
  });
}

import { NextResponse } from "next/server";
import { auth } from "@/auth";
import { getProduct } from "@/lib/data/products";
import {
  isProductSaved,
  saveProduct,
  unsaveProduct,
} from "@/lib/data/saves";

export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { id } = await context.params;
  const product = await getProduct(id);
  if (!product) {
    return NextResponse.json({ error: "Product not found" }, { status: 404 });
  }

  const saved = await isProductSaved(session.user.id, id);
  return NextResponse.json({ saved, productId: id });
}

export async function POST(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { id } = await context.params;
  const product = await getProduct(id);
  if (!product) {
    return NextResponse.json({ error: "Product not found" }, { status: 404 });
  }

  try {
    const result = await saveProduct(session.user.id, id);
    return NextResponse.json({ saved: result.saved, productId: id });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Could not save" },
      { status: 400 },
    );
  }
}

export async function DELETE(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { id } = await context.params;
  try {
    const result = await unsaveProduct(session.user.id, id);
    return NextResponse.json({ saved: result.saved, productId: id });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Could not unsave" },
      { status: 400 },
    );
  }
}

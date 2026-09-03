import { NextResponse } from "next/server";
import { auth } from "@/auth";
import { userHasPurchasedProduct } from "@/lib/data/orders";
import {
  getUserProductReview,
  listReviewsForProduct,
  reviewProduct,
} from "@/lib/data/product-reviews";
import { getProduct } from "@/lib/data/products";

export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const product = await getProduct(id);
  if (!product) {
    return NextResponse.json({ error: "Product not found" }, { status: 404 });
  }

  const session = await auth();
  const reviews = await listReviewsForProduct(id);
  const canReview = session?.user?.id
    ? await userHasPurchasedProduct(session.user.id, id)
    : false;
  const myReview = session?.user?.id
    ? await getUserProductReview(id, session.user.id)
    : undefined;

  return NextResponse.json({
    reviews,
    canReview,
    myReview: myReview ?? null,
    rating: product.rating,
    reviewCount: product.reviewCount,
  });
}

export async function POST(
  request: Request,
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

  const purchased = await userHasPurchasedProduct(session.user.id, id);
  if (!purchased) {
    return NextResponse.json(
      { error: "Buy this product before leaving a review" },
      { status: 403 },
    );
  }

  const body = (await request.json()) as {
    rating?: number;
    text?: string;
  };

  try {
    const review = await reviewProduct({
      productId: id,
      userId: session.user.id,
      userName: session.user.name || "Hubsom shopper",
      rating: Number(body.rating) || 5,
      text: String(body.text ?? ""),
    });
    const updated = await getProduct(id);
    return NextResponse.json({
      review,
      rating: updated?.rating ?? product.rating,
      reviewCount: updated?.reviewCount ?? product.reviewCount,
    });
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error ? error.message : "Could not save review",
      },
      { status: 400 },
    );
  }
}

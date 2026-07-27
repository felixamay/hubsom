import { NextResponse } from "next/server";
import { auth } from "@/auth";
import { createOrder } from "@/lib/data/orders";
import { adjustProductStock, getProduct } from "@/lib/data/products";
import { getEffectivePrice } from "@/lib/pricing";
import type { ProductCategory } from "@/types";

export async function POST(request: Request) {
  const session = await auth();
  const body = (await request.json()) as {
    items?: Array<{ productId: string; quantity: number }>;
    streamId?: string;
    oneTap?: boolean;
  };

  if (!body.items?.length) {
    return NextResponse.json({ error: "items required" }, { status: 400 });
  }

  try {
    const lines = [];
    for (const item of body.items) {
      const product = await getProduct(item.productId);
      if (!product) {
        return NextResponse.json(
          { error: `Unknown product ${item.productId}` },
          { status: 400 },
        );
      }
      if (product.stock < item.quantity) {
        return NextResponse.json(
          { error: `Insufficient stock for ${product.name}` },
          { status: 409 },
        );
      }
      const unit = getEffectivePrice(product);
      lines.push({
        productId: product.id,
        name: product.name,
        quantity: item.quantity,
        unitPriceGhs: unit,
        lineTotalGhs: unit * item.quantity,
        category: product.category as ProductCategory,
      });
    }

    const subtotalGhs = lines.reduce((sum, l) => sum + l.lineTotalGhs, 0);

    for (const line of lines) {
      await adjustProductStock(line.productId, -line.quantity);
    }

    const order = await createOrder({
      currency: "GHS",
      subtotalGhs,
      status: "pending_payment",
      userId: session?.user?.id,
      streamId: body.streamId,
      oneTap: Boolean(body.oneTap),
      lines,
      paymentMethods: ["Mobile Money", "Card", "Hubsom Pay"],
      deliveryEstimate: "Same-day Accra · 1–3 days nationwide",
    });

    return NextResponse.json({
      orderId: order.id,
      currency: order.currency,
      subtotalGhs: order.subtotalGhs,
      deliveryEstimate: order.deliveryEstimate,
      paymentMethods: order.paymentMethods,
      streamId: order.streamId,
      oneTap: order.oneTap,
      lines: order.lines,
      status: order.status,
      createdAt: order.createdAt,
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Checkout failed" },
      { status: 500 },
    );
  }
}

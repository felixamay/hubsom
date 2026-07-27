import { NextResponse } from "next/server";
import { getEffectivePrice, getProduct } from "@/lib/data/products";

export async function POST(request: Request) {
  const body = (await request.json()) as {
    items?: Array<{ productId: string; quantity: number }>;
    streamId?: string;
    oneTap?: boolean;
  };

  if (!body.items?.length) {
    return NextResponse.json({ error: "items required" }, { status: 400 });
  }

  const lines = body.items.map((item) => {
    const product = getProduct(item.productId);
    if (!product) throw new Error(`Unknown product ${item.productId}`);
    const unit = getEffectivePrice(product);
    return {
      productId: product.id,
      name: product.name,
      quantity: item.quantity,
      unitPriceGhs: unit,
      lineTotalGhs: unit * item.quantity,
      category: product.category,
    };
  });

  const subtotalGhs = lines.reduce((sum, l) => sum + l.lineTotalGhs, 0);

  return NextResponse.json({
    orderId: `ord_${Date.now().toString(36)}`,
    currency: "GHS",
    subtotalGhs,
    deliveryEstimate: "Same-day Accra · 1–3 days nationwide",
    paymentMethods: ["Mobile Money", "Card", "Hubsom Pay"],
    streamId: body.streamId,
    oneTap: Boolean(body.oneTap),
    lines,
    status: "confirmed",
  });
}

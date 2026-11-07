import {
  createOrder,
  normalizeShipping,
  type Order,
  type OrderShipping,
} from "@/lib/data/orders";
import { applyStockDeltas, getProduct } from "@/lib/data/products";
import { getEffectivePrice } from "@/lib/pricing";
import type { ProductCategory } from "@/types";
import type { OrderLine } from "@/types/orders";

export type CheckoutItemInput = {
  productId?: string;
  quantity?: number;
};

export type CheckoutInput = {
  items: CheckoutItemInput[];
  shipping?: Partial<OrderShipping>;
  userId?: string;
  buyerName?: string;
  buyerEmail?: string;
  streamId?: string;
  oneTap?: boolean;
};

export type CheckoutResult = {
  order: Order;
  lines: OrderLine[];
};

function parseQuantity(value: unknown): number {
  const qty = typeof value === "number" ? value : Number(value);
  if (!Number.isInteger(qty) || qty < 1) {
    throw new Error("Each item needs a quantity of at least 1");
  }
  return qty;
}

export async function fulfillCheckout(
  input: CheckoutInput,
): Promise<CheckoutResult> {
  if (!input.items?.length) {
    throw new Error("items required");
  }

  const shipping = normalizeShipping(input.shipping);
  const lines: OrderLine[] = [];

  for (const item of input.items) {
    const productId = String(item.productId ?? "").trim();
    if (!productId) {
      throw new Error("productId required");
    }
    const quantity = parseQuantity(item.quantity);
    const product = await getProduct(productId);
    if (!product) {
      throw new Error(`Unknown product ${productId}`);
    }
    const unit = getEffectivePrice(product);
    lines.push({
      productId: product.id,
      sellerId: product.sellerId,
      name: product.name,
      image: product.images[0],
      quantity,
      unitPriceGhs: unit,
      lineTotalGhs: unit * quantity,
      category: product.category as ProductCategory,
    });
  }

  const deltas = lines.map((line) => ({
    productId: line.productId,
    delta: -line.quantity,
  }));

  // One locked catalog write: every line must fit remaining stock, or none move.
  await applyStockDeltas(deltas);

  const subtotalGhs = lines.reduce((sum, l) => sum + l.lineTotalGhs, 0);

  try {
    const order = await createOrder({
      currency: "GHS",
      subtotalGhs,
      status: "pending_payment",
      userId: input.userId,
      buyerName: input.buyerName || shipping.recipientName,
      buyerEmail: input.buyerEmail,
      streamId: input.streamId,
      oneTap: Boolean(input.oneTap),
      lines,
      shipping,
      paymentMethods: ["Mobile Money", "Card", "Hubsom Pay"],
      deliveryEstimate: "Same-day Accra · 1–3 days nationwide",
    });
    return { order, lines };
  } catch (error) {
    await applyStockDeltas(
      lines.map((line) => ({
        productId: line.productId,
        delta: line.quantity,
      })),
    );
    throw error;
  }
}

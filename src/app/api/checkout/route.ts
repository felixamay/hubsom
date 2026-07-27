import { NextResponse } from "next/server";
import { auth } from "@/auth";
import {
  createOrder,
  formatShippingBlock,
  normalizeShipping,
  type OrderShipping,
} from "@/lib/data/orders";
import { sendDirectMessage } from "@/lib/data/messages";
import { adjustProductStock, getProduct } from "@/lib/data/products";
import { getSeller } from "@/lib/data/sellers";
import { getUserById, listUsers, upsertAddress } from "@/lib/data/users";
import { formatGhs } from "@/lib/currency";
import { getEffectivePrice } from "@/lib/pricing";
import type { ProductCategory } from "@/types";

export async function POST(request: Request) {
  const session = await auth();
  const body = (await request.json()) as {
    items?: Array<{ productId: string; quantity: number }>;
    streamId?: string;
    oneTap?: boolean;
    shipping?: Partial<OrderShipping>;
    addressId?: string;
    saveAddress?: boolean;
  };

  if (!body.items?.length) {
    return NextResponse.json({ error: "items required" }, { status: 400 });
  }

  try {
    let shippingInput = body.shipping;
    const userId = session?.user?.id;
    const user = userId ? await getUserById(userId) : undefined;

    if (body.addressId && user) {
      const saved = user.addresses.find((a) => a.id === body.addressId);
      if (!saved) {
        return NextResponse.json(
          { error: "Saved address not found" },
          { status: 400 },
        );
      }
      shippingInput = {
        recipientName:
          body.shipping?.recipientName?.trim() || user.name || "Customer",
        phone: body.shipping?.phone?.trim() || saved.phone || user.phone || "",
        line1: saved.line1,
        line2: saved.line2,
        city: saved.city,
        region: saved.region,
        label: saved.label,
        notes: body.shipping?.notes,
      };
    }

    const shipping = normalizeShipping(shippingInput);

    if (userId && body.saveAddress) {
      await upsertAddress(userId, {
        label: shipping.label || "Delivery",
        line1: shipping.line1,
        line2: shipping.line2,
        city: shipping.city,
        region: shipping.region,
        phone: shipping.phone,
        isDefault: true,
      });
    }

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
        sellerId: product.sellerId,
        name: product.name,
        image: product.images[0],
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
      userId,
      buyerName: user?.name || session?.user?.name || shipping.recipientName,
      buyerEmail: user?.email || session?.user?.email || undefined,
      streamId: body.streamId,
      oneTap: Boolean(body.oneTap),
      lines,
      shipping,
      paymentMethods: ["Mobile Money", "Card", "Hubsom Pay"],
      deliveryEstimate: "Same-day Accra · 1–3 days nationwide",
    });

    // Notify each seller with product lines + shipping for their items.
    const bySeller = new Map<string, typeof lines>();
    for (const line of lines) {
      const list = bySeller.get(line.sellerId) ?? [];
      list.push(line);
      bySeller.set(line.sellerId, list);
    }

    if (userId) {
      const allUsers = await listUsers();
      for (const [sellerId, sellerLines] of bySeller) {
        const seller = await getSeller(sellerId);
        const ownerId =
          seller?.ownerUserId ??
          allUsers.find((u) => u.sellerId === sellerId)?.id;
        if (!ownerId || ownerId === userId) continue;

        const productBlock = sellerLines
          .map(
            (l) =>
              `• ${l.name} ×${l.quantity} — ${formatGhs(l.lineTotalGhs)} (${l.category})`,
          )
          .join("\n");
        const sellerSubtotal = sellerLines.reduce(
          (sum, l) => sum + l.lineTotalGhs,
          0,
        );

        const text = [
          `New Hubsom order ${order.id}`,
          `Buyer: ${order.buyerName ?? shipping.recipientName}`,
          order.buyerEmail ? `Email: ${order.buyerEmail}` : null,
          "",
          "Products:",
          productBlock,
          `Subtotal: ${formatGhs(sellerSubtotal)}`,
          "",
          "Ship to:",
          formatShippingBlock(shipping),
          "",
          `Status: ${order.status.replace("_", " ")}`,
          order.streamId ? `From live: ${order.streamId}` : null,
        ]
          .filter((line) => line !== null)
          .join("\n");

        try {
          await sendDirectMessage({
            fromUserId: userId,
            toUserId: ownerId,
            text,
          });
        } catch {
          /* non-blocking */
        }
      }
    }

    return NextResponse.json({
      orderId: order.id,
      currency: order.currency,
      subtotalGhs: order.subtotalGhs,
      deliveryEstimate: order.deliveryEstimate,
      paymentMethods: order.paymentMethods,
      streamId: order.streamId,
      oneTap: order.oneTap,
      lines: order.lines,
      shipping: order.shipping,
      status: order.status,
      createdAt: order.createdAt,
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Checkout failed" },
      { status: 400 },
    );
  }
}

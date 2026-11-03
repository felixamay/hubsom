import { randomBytes } from "crypto";
import type { Order, OrderLine } from "@/types/orders";

export function newOrderId(): string {
  return `ord_${Date.now().toString(36)}_${randomBytes(4).toString("hex")}`;
}

/** True when every line on the order belongs to this seller. */
export function sellerOwnsEntireOrder(
  order: Pick<Order, "lines">,
  sellerId: string,
): boolean {
  return (
    order.lines.length > 0 &&
    order.lines.every((line) => line.sellerId === sellerId)
  );
}

export function sellerOrderMutationAccess(
  order: Pick<Order, "lines">,
  sellerId: string,
): { ok: true } | { ok: false; status: 403 | 409; error: string } {
  if (!order.lines.some((line) => line.sellerId === sellerId)) {
    return { ok: false, status: 403, error: "Not your order" };
  }
  if (!sellerOwnsEntireOrder(order, sellerId)) {
    return {
      ok: false,
      status: 409,
      error:
        "This purchase includes other sellers' items. You can only update an order that is entirely yours.",
    };
  }
  return { ok: true };
}

/** Split cart lines into one bucket per seller so mixed checkouts stay isolated. */
export function groupOrderLinesBySeller<T extends { sellerId?: string }>(
  lines: T[],
): Map<string, T[]> {
  const bySeller = new Map<string, T[]>();
  for (const line of lines) {
    const sellerId = line.sellerId?.trim();
    if (!sellerId) {
      throw new Error("Every order line needs a sellerId");
    }
    const list = bySeller.get(sellerId) ?? [];
    list.push(line);
    bySeller.set(sellerId, list);
  }
  return bySeller;
}

export function subtotalForLines(
  lines: Pick<OrderLine, "lineTotalGhs">[],
): number {
  return lines.reduce((sum, line) => sum + line.lineTotalGhs, 0);
}

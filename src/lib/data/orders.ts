import { randomBytes } from "crypto";
import { mutateJsonFile, readJsonFile } from "@/lib/data/persist";
import {
  formatShippingBlock,
  mapsSearchUrl,
  normalizeGeoLocation,
  normalizeShipping,
} from "@/lib/shipping";
import type {
  Order,
  OrderShipping,
  OrderStatus,
} from "@/types/orders";

export type {
  GeoLocation,
  Order,
  OrderLine,
  OrderShipping,
  OrderStatus,
} from "@/types/orders";

export {
  formatShippingBlock,
  mapsSearchUrl,
  normalizeGeoLocation,
  normalizeShipping,
};

const FILE = "orders.json";
const EMPTY: Store = { orders: [] };
type Store = { orders: Order[] };

async function load(): Promise<Store> {
  return readJsonFile<Store>(FILE, EMPTY);
}

async function mutateStore(
  mutate: (store: Store) => void | Store | Promise<void | Store>,
): Promise<Store> {
  return mutateJsonFile(FILE, EMPTY, mutate);
}

export async function listOrders(): Promise<Order[]> {
  const store = await load();
  return store.orders;
}

export async function listOrdersByUser(userId: string): Promise<Order[]> {
  const store = await load();
  return store.orders.filter((o) => o.userId === userId);
}

export async function listOrdersBySeller(sellerId: string): Promise<Order[]> {
  const store = await load();
  return store.orders.filter((o) =>
    o.lines.some((line) => line.sellerId === sellerId),
  );
}

export async function getOrder(id: string): Promise<Order | undefined> {
  const store = await load();
  return store.orders.find((o) => o.id === id);
}

export async function createOrder(
  input: Omit<Order, "id" | "createdAt">,
): Promise<Order> {
  let order: Order | undefined;
  await mutateStore((store) => {
    order = {
      ...input,
      shipping: normalizeShipping(input.shipping),
      id: `ord_${Date.now().toString(36)}_${randomBytes(3).toString("hex")}`,
      createdAt: new Date().toISOString(),
    };
    store.orders.unshift(order);
  });
  return order!;
}

export async function updateOrderStatus(
  orderId: string,
  status: OrderStatus,
): Promise<Order | undefined> {
  let updated: Order | undefined;
  await mutateStore((store) => {
    const idx = store.orders.findIndex((o) => o.id === orderId);
    if (idx < 0) return;
    store.orders[idx] = { ...store.orders[idx], status };
    updated = store.orders[idx];
  });
  return updated;
}

export async function updateOrderShipping(
  orderId: string,
  shipping: Partial<OrderShipping>,
): Promise<Order | undefined> {
  let updated: Order | undefined;
  await mutateStore((store) => {
    const idx = store.orders.findIndex((o) => o.id === orderId);
    if (idx < 0) return;
    const current = store.orders[idx].shipping;
    const merged = normalizeShipping({
      ...current,
      ...shipping,
      location:
        shipping.location !== undefined
          ? shipping.location
          : current?.location,
    });
    store.orders[idx] = { ...store.orders[idx], shipping: merged };
    updated = store.orders[idx];
  });
  return updated;
}

export async function getOrderStats() {
  const orders = await listOrders();
  const paidish = orders.filter((o) => o.status !== "cancelled");
  const revenueGhs = paidish.reduce((sum, o) => sum + o.subtotalGhs, 0);
  const unitsSold = paidish.reduce(
    (sum, o) => sum + o.lines.reduce((n, l) => n + l.quantity, 0),
    0,
  );
  const buyers = paidish.length;
  return { revenueGhs, unitsSold, uniqueBuyers: buyers, orderCount: orders.length };
}

/** True when the user has a non-cancelled order that includes this product. */
export async function userHasPurchasedProduct(
  userId: string,
  productId: string,
): Promise<boolean> {
  const orders = await listOrdersByUser(userId);
  return orders.some(
    (order) =>
      order.status !== "cancelled" &&
      order.lines.some((line) => line.productId === productId),
  );
}

/** Distinct purchased product ids for a user (for review CTAs). */
export async function listPurchasedProductIds(
  userId: string,
): Promise<string[]> {
  const orders = await listOrdersByUser(userId);
  const ids = new Set<string>();
  for (const order of orders) {
    if (order.status === "cancelled") continue;
    for (const line of order.lines) ids.add(line.productId);
  }
  return Array.from(ids);
}

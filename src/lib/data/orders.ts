import { readJsonFile, writeJsonFile } from "@/lib/data/persist";
import type { ProductCategory } from "@/types";

export type OrderStatus = "pending_payment" | "paid" | "fulfilled" | "cancelled";

export interface OrderShipping {
  recipientName: string;
  phone: string;
  line1: string;
  line2?: string;
  city: string;
  region: string;
  notes?: string;
  label?: string;
}

export interface OrderLine {
  productId: string;
  sellerId?: string;
  name: string;
  image?: string;
  quantity: number;
  unitPriceGhs: number;
  lineTotalGhs: number;
  category: ProductCategory;
}

export interface Order {
  id: string;
  currency: "GHS";
  subtotalGhs: number;
  status: OrderStatus;
  userId?: string;
  buyerName?: string;
  buyerEmail?: string;
  streamId?: string;
  oneTap?: boolean;
  lines: OrderLine[];
  shipping?: OrderShipping;
  paymentMethods: string[];
  deliveryEstimate: string;
  createdAt: string;
}

const FILE = "orders.json";
type Store = { orders: Order[] };

async function load(): Promise<Store> {
  return readJsonFile<Store>(FILE, { orders: [] });
}

async function save(store: Store) {
  await writeJsonFile(FILE, store);
}

export function normalizeShipping(
  input: Partial<OrderShipping> | undefined,
): OrderShipping {
  const recipientName = String(input?.recipientName ?? "").trim();
  const phone = String(input?.phone ?? "").trim();
  const line1 = String(input?.line1 ?? "").trim();
  const line2 = String(input?.line2 ?? "").trim() || undefined;
  const city = String(input?.city ?? "").trim() || "Accra";
  const region = String(input?.region ?? "").trim() || "Greater Accra";
  const notes = String(input?.notes ?? "").trim() || undefined;
  const label = String(input?.label ?? "").trim() || undefined;

  if (!recipientName) throw new Error("Recipient name is required");
  if (!phone) throw new Error("Phone number is required for delivery");
  if (!line1) throw new Error("Shipping address is required");

  return {
    recipientName,
    phone,
    line1,
    line2,
    city,
    region,
    notes,
    label,
  };
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
  const store = await load();
  const order: Order = {
    ...input,
    shipping: normalizeShipping(input.shipping),
    id: `ord_${Date.now().toString(36)}`,
    createdAt: new Date().toISOString(),
  };
  store.orders.unshift(order);
  await save(store);
  return order;
}

export async function updateOrderStatus(
  orderId: string,
  status: OrderStatus,
): Promise<Order | undefined> {
  const store = await load();
  const idx = store.orders.findIndex((o) => o.id === orderId);
  if (idx < 0) return undefined;
  store.orders[idx] = { ...store.orders[idx], status };
  await save(store);
  return store.orders[idx];
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

export function formatShippingBlock(shipping: OrderShipping): string {
  return [
    shipping.recipientName,
    shipping.phone,
    shipping.line1,
    shipping.line2,
    `${shipping.city}, ${shipping.region}`,
    shipping.notes ? `Note: ${shipping.notes}` : null,
  ]
    .filter(Boolean)
    .join("\n");
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

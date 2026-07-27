import { readJsonFile, writeJsonFile } from "@/lib/data/persist";
import type { ProductCategory } from "@/types";

export type OrderStatus = "pending_payment" | "paid" | "fulfilled" | "cancelled";

export interface OrderLine {
  productId: string;
  name: string;
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
  streamId?: string;
  oneTap?: boolean;
  lines: OrderLine[];
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

export async function listOrders(): Promise<Order[]> {
  const store = await load();
  return store.orders;
}

export async function createOrder(
  input: Omit<Order, "id" | "createdAt">,
): Promise<Order> {
  const store = await load();
  const order: Order = {
    ...input,
    id: `ord_${Date.now().toString(36)}`,
    createdAt: new Date().toISOString(),
  };
  store.orders.unshift(order);
  await save(store);
  return order;
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

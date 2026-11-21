import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { after, test } from "node:test";
import { adjustProductStock, createProduct, getProduct } from "./products";
import { createOrder, updateOrderStatus } from "./orders";

const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), "hubsom-restock-"));
process.env.HUBSOM_DATA_DIR = dataDir;

const IMAGES = [
  "/uploads/products/a.jpg",
  "/uploads/products/b.jpg",
  "/uploads/products/c.jpg",
];

const SHIPPING = {
  recipientName: "Ama Buyer",
  phone: "0240000000",
  line1: "12 Independence Ave",
  city: "Accra",
  region: "Greater Accra",
};

async function listedProduct(stock: number) {
  return createProduct({
    name: `Restock fixture ${Date.now()}-${Math.random()}`,
    category: "groceries",
    priceGhs: 40,
    stock,
    sellerId: "seller-you",
    images: IMAGES,
  });
}

async function reservedOrder(
  productId: string,
  quantity: number,
  status: "pending_payment" | "paid" | "fulfilled",
) {
  const product = await getProduct(productId);
  assert.ok(product);
  await adjustProductStock(productId, -quantity);
  return createOrder({
    currency: "GHS",
    subtotalGhs: 40 * quantity,
    status,
    userId: "user-buyer",
    buyerName: "Ama Buyer",
    lines: [
      {
        productId,
        sellerId: "seller-you",
        name: product.name,
        image: product.images[0],
        quantity,
        unitPriceGhs: 40,
        lineTotalGhs: 40 * quantity,
        category: "groceries",
      },
    ],
    shipping: SHIPPING,
    paymentMethods: ["Mobile Money"],
    deliveryEstimate: "Same-day Accra",
  });
}

after(() => {
  fs.rmSync(dataDir, { recursive: true, force: true });
});

test("cancelling a pending_payment order restores reserved stock", async () => {
  const product = await listedProduct(5);
  const order = await reservedOrder(product.id, 2, "pending_payment");
  assert.equal((await getProduct(product.id))?.stock, 3);

  const updated = await updateOrderStatus(order.id, "cancelled");
  assert.equal(updated?.status, "cancelled");
  assert.equal((await getProduct(product.id))?.stock, 5);
});

test("cancelling a paid unshipped order restores stock", async () => {
  const product = await listedProduct(4);
  const order = await reservedOrder(product.id, 1, "paid");
  assert.equal((await getProduct(product.id))?.stock, 3);

  await updateOrderStatus(order.id, "cancelled");
  assert.equal((await getProduct(product.id))?.stock, 4);
});

test("a second cancel does not restock twice", async () => {
  const product = await listedProduct(2);
  const order = await reservedOrder(product.id, 2, "pending_payment");
  assert.equal((await getProduct(product.id))?.stock, 0);

  await updateOrderStatus(order.id, "cancelled");
  await updateOrderStatus(order.id, "cancelled");
  assert.equal((await getProduct(product.id))?.stock, 2);
});

test("concurrent cancels restock once", async () => {
  const product = await listedProduct(1);
  const order = await reservedOrder(product.id, 1, "pending_payment");
  assert.equal((await getProduct(product.id))?.stock, 0);

  await Promise.all([
    updateOrderStatus(order.id, "cancelled"),
    updateOrderStatus(order.id, "cancelled"),
  ]);
  assert.equal((await getProduct(product.id))?.stock, 1);
});

test("cancelling a fulfilled order does not restock shipped goods", async () => {
  const product = await listedProduct(6);
  const order = await reservedOrder(product.id, 3, "fulfilled");
  assert.equal((await getProduct(product.id))?.stock, 3);

  await updateOrderStatus(order.id, "cancelled");
  assert.equal((await getProduct(product.id))?.stock, 3);
});

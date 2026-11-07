import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { before, test } from "node:test";
import { fulfillCheckout } from "./checkout";
import { listOrders } from "./data/orders";
import { getDataDir, readJsonFile, withLock } from "./data/persist";
import { createProduct, getProduct } from "./data/products";

const dir = mkdtempSync(path.join(tmpdir(), "hubsom-checkout-"));
process.env.HUBSOM_DATA_DIR = dir;

const shipping = {
  recipientName: "Ama Mensah",
  phone: "0240000000",
  line1: "12 Oxford Street",
  city: "Accra",
  region: "Greater Accra",
};

const images = [
  "/uploads/products/a.jpg",
  "/uploads/products/b.jpg",
  "/uploads/products/c.jpg",
];

async function listProduct(name: string, stock: number) {
  return createProduct({
    name,
    category: "groceries",
    priceGhs: 40,
    stock,
    sellerId: "seller-test",
    images,
  });
}

before(() => {
  assert.equal(getDataDir(), dir);
});

test("withLock serializes overlapping read-modify-write", async () => {
  let value = 0;
  async function inc() {
    const read = value;
    await new Promise((r) => setTimeout(r, 20));
    value = read + 1;
  }

  await Promise.all([withLock("counter", inc), withLock("counter", inc)]);
  assert.equal(value, 2);
});

test("two buyers of the last unit: one order, stock stays 0", async () => {
  const product = await listProduct(`Last unit ${Date.now()}`, 1);

  const results = await Promise.allSettled([
    fulfillCheckout({
      items: [{ productId: product.id, quantity: 1 }],
      shipping,
      buyerName: "Buyer A",
    }),
    fulfillCheckout({
      items: [{ productId: product.id, quantity: 1 }],
      shipping,
      buyerName: "Buyer B",
    }),
  ]);

  const won = results.filter((r) => r.status === "fulfilled");
  const lost = results.filter((r) => r.status === "rejected");
  assert.equal(won.length, 1);
  assert.equal(lost.length, 1);
  assert.match(
    String((lost[0] as PromiseRejectedResult).reason),
    /insufficient stock/i,
  );

  const remaining = await getProduct(product.id);
  assert.equal(remaining?.stock, 0);

  const orders = (await listOrders()).filter((o) =>
    o.lines.some((l) => l.productId === product.id),
  );
  assert.equal(orders.length, 1);
});

test("concurrent checkouts of different SKUs both persist", async () => {
  const stamp = Date.now();
  const a = await listProduct(`Yam ${stamp}`, 2);
  const b = await listProduct(`Plantain ${stamp}`, 2);

  const [first, second] = await Promise.all([
    fulfillCheckout({
      items: [{ productId: a.id, quantity: 1 }],
      shipping,
      buyerName: "Buyer A",
    }),
    fulfillCheckout({
      items: [{ productId: b.id, quantity: 1 }],
      shipping,
      buyerName: "Buyer B",
    }),
  ]);

  const orders = await listOrders();
  assert.ok(orders.some((o) => o.id === first.order.id));
  assert.ok(orders.some((o) => o.id === second.order.id));
  assert.equal((await getProduct(a.id))?.stock, 1);
  assert.equal((await getProduct(b.id))?.stock, 1);
});

test("split cart rows cannot take more than remaining stock", async () => {
  const product = await listProduct(`Split ${Date.now()}`, 1);

  await assert.rejects(
    () =>
      fulfillCheckout({
        items: [
          { productId: product.id, quantity: 1 },
          { productId: product.id, quantity: 1 },
        ],
        shipping,
      }),
    /insufficient stock/i,
  );

  assert.equal((await getProduct(product.id))?.stock, 1);
  const orders = (await listOrders()).filter((o) =>
    o.lines.some((l) => l.productId === product.id),
  );
  assert.equal(orders.length, 0);
});

test("corrupt ledger file is not wiped to empty", async () => {
  const file = path.join(dir, "wipe-check.json");
  writeFileSync(file, "{not-json", "utf8");
  await assert.rejects(() => readJsonFile("wipe-check.json", { orders: [] }));
  assert.equal(readFileSync(file, "utf8"), "{not-json");
});

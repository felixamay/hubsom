import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile, mkdir } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { createConsolidatedShipment } from "./shipments";

const shipping = {
  recipientName: "Kojo Buyer",
  phone: "0241111111",
  line1: "12 Spintex Rd",
  city: "Accra",
  region: "Greater Accra",
};

function order(id: string, status: string) {
  return {
    id,
    currency: "GHS",
    subtotalGhs: 80,
    status,
    userId: "buyer-1",
    buyerName: "Kojo Buyer",
    lines: [
      {
        productId: "prod-1",
        sellerId: "seller-1",
        name: "Wax print",
        quantity: 1,
        unitPriceGhs: 80,
        lineTotalGhs: 80,
        category: "fashion",
      },
    ],
    shipping,
    paymentMethods: ["Mobile Money"],
    deliveryEstimate: "Same-day Accra",
    createdAt: new Date().toISOString(),
  };
}

async function withStore(
  orders: ReturnType<typeof order>[],
  fn: () => Promise<void>,
) {
  const dir = await mkdtemp(path.join(os.tmpdir(), "hubsom-ship-"));
  const prev = process.cwd();
  try {
    process.chdir(dir);
    await mkdir(".data", { recursive: true });
    await writeFile(
      path.join(dir, ".data", "orders.json"),
      JSON.stringify({ orders }, null, 2),
    );
    await writeFile(
      path.join(dir, ".data", "shipments.json"),
      JSON.stringify({ shipments: [] }, null, 2),
    );
    await fn();
  } finally {
    process.chdir(prev);
    await rm(dir, { recursive: true, force: true });
  }
}

test("createConsolidatedShipment refuses pending_payment orders", async () => {
  await withStore([order("ord_unpaid", "pending_payment")], async () => {
    await assert.rejects(
      () =>
        createConsolidatedShipment({
          sellerId: "seller-1",
          createdByUserId: "seller-user",
          orderIds: ["ord_unpaid"],
        }),
      /mark it paid before shipping/,
    );
  });
});

test("createConsolidatedShipment accepts a paid order", async () => {
  await withStore([order("ord_paid", "paid")], async () => {
    const shipment = await createConsolidatedShipment({
      sellerId: "seller-1",
      createdByUserId: "seller-user",
      orderIds: ["ord_paid"],
    });
    assert.equal(shipment.orderIds[0], "ord_paid");
    assert.equal(shipment.items[0]?.productId, "prod-1");
  });
});

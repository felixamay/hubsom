import assert from "node:assert/strict";
import { test } from "node:test";
import type { OrderShipping } from "@/types/orders";
import {
  assertSameDeliveryDestination,
  shipmentGroupKey,
  shippingFingerprint,
} from "@/lib/shipment-destination";

function ship(
  partial: Partial<OrderShipping> &
    Pick<OrderShipping, "recipientName" | "phone" | "line1" | "city">,
): OrderShipping {
  return {
    region: "Greater Accra",
    ...partial,
  };
}

test("same street and phone share a drop-off even if the pin differs", () => {
  const amaAccra = ship({
    recipientName: "Ama Buyer",
    phone: "024-111-1111",
    line1: "12 Spintex Rd",
    city: "Accra",
    location: { latitude: 5.63, longitude: -0.17 },
  });
  const amaAgain = ship({
    recipientName: "AMA BUYER",
    phone: "0241111111",
    line1: "12 Spintex Rd",
    city: "Accra",
    location: { latitude: 5.64, longitude: -0.18 },
  });
  assert.equal(shippingFingerprint(amaAccra), shippingFingerprint(amaAgain));
  assert.doesNotThrow(() =>
    assertSameDeliveryDestination([
      { id: "ord_a", shipping: amaAccra },
      { id: "ord_b", shipping: amaAgain },
    ]),
  );
});

test("two buyers cannot share one Huber drop-off", () => {
  assert.throws(
    () =>
      assertSameDeliveryDestination([
        {
          id: "ord_ama",
          shipping: ship({
            recipientName: "Ama Buyer",
            phone: "0241111111",
            line1: "12 Spintex Rd",
            city: "Accra",
          }),
        },
        {
          id: "ord_kojo",
          shipping: ship({
            recipientName: "Kojo Buyer",
            phone: "0242222222",
            line1: "4 Kejetia",
            city: "Kumasi",
            region: "Ashanti",
          }),
        },
      ]),
    /different buyers or addresses/,
  );
});

test("orders without an address never collapse onto Accra together", () => {
  const a = shipmentGroupKey({ id: "ord_1" });
  const b = shipmentGroupKey({ id: "ord_2" });
  assert.notEqual(a, b);
  assert.throws(
    () =>
      assertSameDeliveryDestination([{ id: "ord_1" }, { id: "ord_2" }]),
    /different buyers or addresses/,
  );
});

test("createConsolidatedShipment refuses mixed drop-offs", async () => {
  const { createOrder } = await import("@/lib/data/orders");
  const { createConsolidatedShipment } = await import("@/lib/data/shipments");
  const sellerId = `seller-dest-${Date.now().toString(36)}`;
  const line = (name: string, city: string, phone: string) => ({
    productId: `prod-${phone}`,
    sellerId,
    name,
    quantity: 1,
    unitPriceGhs: 40,
    lineTotalGhs: 40,
    category: "fashion" as const,
  });
  const ama = await createOrder({
    currency: "GHS",
    subtotalGhs: 40,
    status: "paid",
    lines: [line("Wax print", "Accra", "0241111111")],
    shipping: ship({
      recipientName: "Ama Buyer",
      phone: "0241111111",
      line1: "12 Spintex Rd",
      city: "Accra",
    }),
    paymentMethods: ["Mobile Money"],
    deliveryEstimate: "Same-day Accra",
  });
  await new Promise((r) => setTimeout(r, 5));
  const kojo = await createOrder({
    currency: "GHS",
    subtotalGhs: 40,
    status: "paid",
    lines: [line("Kente", "Kumasi", "0242222222")],
    shipping: ship({
      recipientName: "Kojo Buyer",
      phone: "0242222222",
      line1: "4 Kejetia",
      city: "Kumasi",
      region: "Ashanti",
    }),
    paymentMethods: ["Mobile Money"],
    deliveryEstimate: "1–3 days",
  });

  await assert.rejects(
    () =>
      createConsolidatedShipment({
        sellerId,
        createdByUserId: "user-dest-test",
        orderIds: [ama.id, kojo.id],
      }),
    /different buyers or addresses/,
  );

  const sameAddress = await createConsolidatedShipment({
    sellerId,
    createdByUserId: "user-dest-test",
    orderIds: [ama.id],
  });
  assert.equal(sameAddress.destination.recipientName, "Ama Buyer");
  assert.deepEqual(sameAddress.orderIds, [ama.id]);
});

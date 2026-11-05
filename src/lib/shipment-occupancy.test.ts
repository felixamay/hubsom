import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  assertOrdersFreeToShip,
  occupiedOrderIdsForSeller,
  shipmentOccupiesOrders,
} from "./shipment-occupancy.ts";

function lot(input: {
  sellerId?: string;
  status: string;
  orderIds: string[];
}) {
  return {
    sellerId: input.sellerId ?? "seller-ama",
    status: input.status,
    orderIds: input.orderIds,
  };
}

describe("shipmentOccupiesOrders", () => {
  it("frees orders only when the lot is cancelled", () => {
    assert.equal(shipmentOccupiesOrders("cancelled"), false);
  });

  it("keeps orders occupied after delivery so a second rider cannot be paid", () => {
    for (const status of [
      "draft",
      "ready",
      "offering",
      "assigned",
      "out_for_delivery",
      "delivered",
    ] as const) {
      assert.equal(shipmentOccupiesOrders(status), true, status);
    }
  });
});

describe("occupiedOrderIdsForSeller", () => {
  it("blocks re-consolidating an order that is already on a live or delivered lot", () => {
    const occupied = occupiedOrderIdsForSeller(
      [
        lot({ status: "assigned", orderIds: ["ord_paid"] }),
        lot({ status: "delivered", orderIds: ["ord_done"] }),
        lot({ status: "cancelled", orderIds: ["ord_free"] }),
        lot({
          sellerId: "seller-other",
          status: "ready",
          orderIds: ["ord_other_store"],
        }),
      ],
      "seller-ama",
    );

    assert.equal(occupied.has("ord_paid"), true);
    assert.equal(occupied.has("ord_done"), true);
    assert.equal(occupied.has("ord_free"), false);
    assert.equal(occupied.has("ord_other_store"), false);
  });

  it("lets a later unpaid order stay available after the first lot is cancelled", () => {
    const occupied = occupiedOrderIdsForSeller(
      [lot({ status: "cancelled", orderIds: ["ord_a"] })],
      "seller-ama",
    );
    assert.equal(occupied.has("ord_a"), false);
  });
});

describe("assertOrdersFreeToShip", () => {
  it("rejects consolidating a paid order that is already on a delivered lot", () => {
    const occupied = occupiedOrderIdsForSeller(
      [lot({ status: "delivered", orderIds: ["ord_paid"] })],
      "seller-ama",
    );
    assert.throws(
      () => assertOrdersFreeToShip(["ord_paid"], occupied),
      /Order ord_paid is already on a shipment/,
    );
  });

  it("allows a new order after the first shipment, and a retry after cancel", () => {
    const afterFirst = occupiedOrderIdsForSeller(
      [lot({ status: "ready", orderIds: ["ord_a"] })],
      "seller-ama",
    );
    assert.doesNotThrow(() => assertOrdersFreeToShip(["ord_b"], afterFirst));
    assert.throws(() => assertOrdersFreeToShip(["ord_a"], afterFirst));

    const afterCancel = occupiedOrderIdsForSeller(
      [lot({ status: "cancelled", orderIds: ["ord_a"] })],
      "seller-ama",
    );
    assert.doesNotThrow(() => assertOrdersFreeToShip(["ord_a"], afterCancel));
  });
});

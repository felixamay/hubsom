import assert from "node:assert/strict";
import { test } from "node:test";
import {
  isShippableOrderStatus,
  unpaidShipmentError,
} from "./shippable-status";

test("only paid and processing orders may be shipped", () => {
  assert.equal(isShippableOrderStatus("paid"), true);
  assert.equal(isShippableOrderStatus("processing"), true);
  assert.equal(isShippableOrderStatus("pending_payment"), false);
  assert.equal(isShippableOrderStatus("cancelled"), false);
  assert.equal(isShippableOrderStatus("fulfilled"), false);
  assert.equal(isShippableOrderStatus("shipped"), false);
});

test("unpaid shipment error names the order and status", () => {
  assert.equal(
    unpaidShipmentError("ord_abc", "pending_payment"),
    "Order ord_abc is pending payment; mark it paid before shipping",
  );
});

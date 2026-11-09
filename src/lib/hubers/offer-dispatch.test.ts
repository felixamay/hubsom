import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  assertShipmentCanAcceptNewOffers,
  shipmentCanAcceptNewOffers,
} from "./offer-dispatch.ts";

describe("shipmentCanAcceptNewOffers", () => {
  it("allows the first dispatch and a retry while still offering", () => {
    for (const status of ["draft", "ready", "offering"] as const) {
      assert.equal(shipmentCanAcceptNewOffers(status), true, status);
    }
  });

  it("blocks re-offer after a rider has the job so a second rider cannot be paid", () => {
    for (const status of [
      "assigned",
      "out_for_delivery",
      "delivered",
      "cancelled",
    ] as const) {
      assert.equal(shipmentCanAcceptNewOffers(status), false, status);
    }
  });
});

describe("assertShipmentCanAcceptNewOffers", () => {
  it("rejects tapping Hubers on an assigned shipment", () => {
    assert.throws(
      () => assertShipmentCanAcceptNewOffers("assigned"),
      /already with a rider/,
    );
  });

  it("rejects re-offer while the rider is out for delivery", () => {
    assert.throws(
      () => assertShipmentCanAcceptNewOffers("out_for_delivery"),
      /already with a rider/,
    );
  });

  it("still allows a retry when nobody has accepted yet", () => {
    assert.doesNotThrow(() => assertShipmentCanAcceptNewOffers("offering"));
    assert.doesNotThrow(() => assertShipmentCanAcceptNewOffers("ready"));
  });
});

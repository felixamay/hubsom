import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  DROPOFF_LOCKED_ERROR,
  SELLER_DEVICE_GPS_DROPOFF_ERROR,
  assertNotSellerDeviceGpsPin,
  assertShipmentDropoffMutable,
  shipmentDropoffIsLocked,
} from "./dropoff-guard.ts";

describe("seller drop-off guards", () => {
  it("locks destination after a rider is assigned", () => {
    assert.equal(shipmentDropoffIsLocked("draft"), false);
    assert.equal(shipmentDropoffIsLocked("ready"), false);
    assert.equal(shipmentDropoffIsLocked("offering"), false);
    assert.equal(shipmentDropoffIsLocked("assigned"), true);
    assert.equal(shipmentDropoffIsLocked("out_for_delivery"), true);
    assert.equal(shipmentDropoffIsLocked("delivered"), true);
    assert.equal(shipmentDropoffIsLocked("cancelled"), true);
  });

  it("rejects seller-device GPS as the buyer pin", () => {
    assert.doesNotThrow(() =>
      assertNotSellerDeviceGpsPin({
        latitude: 5.6037,
        longitude: -0.187,
        source: "manual",
      }),
    );
    assert.doesNotThrow(() =>
      assertNotSellerDeviceGpsPin({
        latitude: 5.6037,
        longitude: -0.187,
        source: "geocoded",
      }),
    );
    assert.doesNotThrow(() => assertNotSellerDeviceGpsPin(null));
    assert.throws(
      () =>
        assertNotSellerDeviceGpsPin({
          latitude: 6.6885,
          longitude: -1.6244,
          source: "gps",
        }),
      { message: SELLER_DEVICE_GPS_DROPOFF_ERROR },
    );
  });

  it("blocks destination/location patches after assign, allows status and notes", () => {
    assert.doesNotThrow(() =>
      assertShipmentDropoffMutable("assigned", { status: "out_for_delivery" }),
    );
    assert.doesNotThrow(() =>
      assertShipmentDropoffMutable("assigned", { notes: "rider update" }),
    );
    assert.doesNotThrow(() =>
      assertShipmentDropoffMutable("ready", {
        location: { latitude: 5.6, longitude: -0.2, source: "manual" },
      }),
    );
    assert.throws(
      () =>
        assertShipmentDropoffMutable("assigned", {
          location: { latitude: 6.69, longitude: -1.62, source: "manual" },
        }),
      { message: DROPOFF_LOCKED_ERROR },
    );
    assert.throws(
      () =>
        assertShipmentDropoffMutable("out_for_delivery", {
          destination: { city: "Kumasi" },
        }),
      { message: DROPOFF_LOCKED_ERROR },
    );
  });
});

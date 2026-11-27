import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { mapsSearchUrl } from "./shipping.ts";

describe("mapsSearchUrl", () => {
  it("navigates to the pin even when the street address is different", () => {
    const url = mapsSearchUrl({
      recipientName: "Ama Buyer",
      phone: "0240000000",
      line1: "12 Spintex Rd",
      city: "Accra",
      region: "Greater Accra",
      location: {
        latitude: 6.6885,
        longitude: -1.6244,
        source: "gps",
      },
    });
    assert.match(url, /query=6\.6885,-1\.6244/);
    assert.doesNotMatch(url, /Spintex/);
  });
});

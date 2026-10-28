import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  isStreamHost,
  sanitizeHostStreamPatch,
} from "./host-stream";

describe("isStreamHost", () => {
  const seller = { id: "seller-ama", ownerUserId: "user-ama" };

  it("allows the store owner", () => {
    assert.equal(
      isStreamHost({ userId: "user-ama", userSellerId: "seller-ama", seller }),
      true,
    );
  });

  it("allows a session whose sellerId matches the store", () => {
    assert.equal(
      isStreamHost({
        userId: "user-ama",
        userSellerId: "seller-ama",
        seller: { id: "seller-ama" },
      }),
      true,
    );
  });

  it("rejects a signed-in viewer of someone else's show", () => {
    assert.equal(
      isStreamHost({
        userId: "user-kojo",
        userSellerId: "seller-kojo",
        seller,
      }),
      false,
    );
  });

  it("rejects a missing session or missing seller", () => {
    assert.equal(isStreamHost({ userId: "user-ama", seller: null }), false);
    assert.equal(isStreamHost({ seller }), false);
    assert.equal(
      isStreamHost({ userId: "", userSellerId: "seller-ama", seller }),
      false,
    );
  });
});

describe("sanitizeHostStreamPatch", () => {
  it("keeps a pin update", () => {
    const { patch, error } = sanitizeHostStreamPatch({
      pinnedProductId: "prod-1",
    });
    assert.equal(error, undefined);
    assert.deepEqual(patch, { pinnedProductId: "prod-1" });
  });

  it("maps recording:true to replayAvailable", () => {
    const { patch, error } = sanitizeHostStreamPatch({ recording: true });
    assert.equal(error, undefined);
    assert.deepEqual(patch, { replayAvailable: true });
  });

  it("drops status, auction, and sellerId so a viewer cannot end or steal the lot", () => {
    const { patch, error } = sanitizeHostStreamPatch({
      status: "ended",
      sellerId: "seller-attacker",
      auction: { status: "sold", highestBidder: "Attacker" },
      endedAt: "2026-10-28T11:00:00.000Z",
    });
    assert.equal(error, "No allowed host fields in patch");
    assert.deepEqual(patch, {});
  });

  it("applies the pin and ignores a smuggled status", () => {
    const { patch, error } = sanitizeHostStreamPatch({
      pinnedProductId: "prod-2",
      status: "ended",
      auction: { status: "sold" },
    });
    assert.equal(error, undefined);
    assert.deepEqual(patch, { pinnedProductId: "prod-2" });
  });
});

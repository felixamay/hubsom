import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { parseStockDelta, userOwnsProduct } from "../src/lib/inventory-auth.ts";

describe("parseStockDelta", () => {
  it("defaults to decrementing one unit", () => {
    assert.equal(parseStockDelta(undefined), -1);
    assert.equal(parseStockDelta(null), -1);
  });

  it("accepts integer deltas including restocks", () => {
    assert.equal(parseStockDelta(-3), -3);
    assert.equal(parseStockDelta(12), 12);
    assert.equal(parseStockDelta("4"), 4);
  });

  it("rejects values that would NaN catalog stock", () => {
    assert.equal(parseStockDelta("nope"), undefined);
    assert.equal(parseStockDelta(1.5), undefined);
    assert.equal(parseStockDelta(Number.NaN), undefined);
    assert.equal(parseStockDelta(Number.POSITIVE_INFINITY), undefined);
  });
});

describe("userOwnsProduct", () => {
  it("allows the storefront owner and matching sellerId", () => {
    assert.equal(
      userOwnsProduct({
        userId: "user-1",
        userSellerId: "seller-1",
        productSellerId: "seller-1",
      }),
      true,
    );
    assert.equal(
      userOwnsProduct({
        userId: "user-1",
        productSellerId: "seller-9",
        sellerOwnerUserId: "user-1",
      }),
      true,
    );
  });

  it("rejects a signed-in stranger", () => {
    assert.equal(
      userOwnsProduct({
        userId: "attacker",
        userSellerId: "seller-attacker",
        productSellerId: "seller-victim",
        sellerOwnerUserId: "user-victim",
      }),
      false,
    );
  });

  it("rejects anonymous callers", () => {
    assert.equal(
      userOwnsProduct({
        userId: "",
        productSellerId: "seller-1",
        sellerOwnerUserId: "user-1",
      }),
      false,
    );
  });
});

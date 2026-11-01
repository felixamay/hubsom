import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { parseCheckoutQuantity } from "./checkout-quantity.ts";

describe("parseCheckoutQuantity", () => {
  it("accepts whole units of at least 1", () => {
    assert.equal(parseCheckoutQuantity(1), 1);
    assert.equal(parseCheckoutQuantity(12), 12);
    assert.equal(parseCheckoutQuantity("3"), 3);
  });

  it("rejects missing, zero, and negative quantities that would inflate stock", () => {
    assert.equal(parseCheckoutQuantity(undefined), null);
    assert.equal(parseCheckoutQuantity(null), null);
    assert.equal(parseCheckoutQuantity(0), null);
    assert.equal(parseCheckoutQuantity(-1), null);
    assert.equal(parseCheckoutQuantity(-50), null);
    assert.equal(parseCheckoutQuantity("-2"), null);
  });

  it("rejects non-integers and non-finite values that persist as null stock", () => {
    assert.equal(parseCheckoutQuantity(1.5), null);
    assert.equal(parseCheckoutQuantity(Number.NaN), null);
    assert.equal(parseCheckoutQuantity(Number.POSITIVE_INFINITY), null);
    assert.equal(parseCheckoutQuantity(""), null);
    assert.equal(parseCheckoutQuantity("two"), null);
    assert.equal(parseCheckoutQuantity(true), null);
    assert.equal(parseCheckoutQuantity({}), null);
  });
});

describe("stock persistence", () => {
  it("JSON.stringify turns NaN stock into null, which bricks the listing", () => {
    const persisted = JSON.parse(JSON.stringify({ stock: Number.NaN })) as {
      stock: unknown;
    };
    assert.equal(persisted.stock, null);
    assert.equal((persisted.stock as number) < 1, true);
  });
});

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { parseLineQuantity } from "./checkout-quantity.ts";

describe("parseLineQuantity", () => {
  it("accepts positive integers", () => {
    assert.equal(parseLineQuantity(1), 1);
    assert.equal(parseLineQuantity(3), 3);
  });

  it("rejects negatives that would add stock on checkout", () => {
    assert.equal(parseLineQuantity(-10), null);
  });

  it("rejects zero, fractions, and non-numeric values", () => {
    assert.equal(parseLineQuantity(0), null);
    assert.equal(parseLineQuantity(1.5), null);
    assert.equal(parseLineQuantity("abc"), null);
    assert.equal(parseLineQuantity(undefined), null);
  });
});

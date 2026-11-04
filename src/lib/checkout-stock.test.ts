import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { allocateCatalogStock } from "./checkout-stock.ts";

describe("allocateCatalogStock", () => {
  it("lets distinct products each take their own stock", () => {
    const result = allocateCatalogStock(
      [
        { productId: "hat", quantity: 1 },
        { productId: "bag", quantity: 2 },
      ],
      new Map([
        ["hat", 1],
        ["bag", 5],
      ]),
    );
    assert.equal(result.ok, true);
    if (result.ok) {
      assert.equal(result.consumed.get("hat"), 1);
      assert.equal(result.consumed.get("bag"), 2);
    }
  });

  it("rejects split rows that together exceed listing stock", () => {
    const result = allocateCatalogStock(
      [
        { productId: "sneaker", quantity: 1 },
        { productId: "sneaker", quantity: 1 },
      ],
      new Map([["sneaker", 1]]),
    );
    assert.deepEqual(result, { ok: false, productId: "sneaker" });
  });

  it("allows split live + shop rows when stock covers both", () => {
    const result = allocateCatalogStock(
      [
        { productId: "sneaker", quantity: 1 },
        { productId: "sneaker", quantity: 1 },
      ],
      new Map([["sneaker", 2]]),
    );
    assert.equal(result.ok, true);
    if (result.ok) {
      assert.equal(result.consumed.get("sneaker"), 2);
    }
  });

  it("rejects a later row after an earlier row took the last unit", () => {
    const result = allocateCatalogStock(
      [
        { productId: "wax", quantity: 2 },
        { productId: "wax", quantity: 1 },
      ],
      new Map([["wax", 2]]),
    );
    assert.deepEqual(result, { ok: false, productId: "wax" });
  });
});

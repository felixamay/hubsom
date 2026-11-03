import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { OrderLine } from "../../types/orders.ts";
import {
  groupOrderLinesBySeller,
  newOrderId,
  sellerOrderMutationAccess,
  sellerOwnsEntireOrder,
  subtotalForLines,
} from "./order-scope.ts";

function line(
  sellerId: string,
  productId: string,
  total: number,
): OrderLine {
  return {
    productId,
    sellerId,
    name: productId,
    quantity: 1,
    unitPriceGhs: total,
    lineTotalGhs: total,
    category: "fashion",
  };
}

describe("mixed-seller order isolation", () => {
  it("lets a seller update only when every line is theirs", () => {
    const own = {
      lines: [line("seller-a", "p1", 40), line("seller-a", "p2", 20)],
    };
    const mixed = {
      lines: [line("seller-a", "p1", 40), line("seller-b", "p3", 80)],
    };

    assert.equal(sellerOwnsEntireOrder(own, "seller-a"), true);
    assert.equal(sellerOwnsEntireOrder(mixed, "seller-a"), false);
    assert.equal(sellerOwnsEntireOrder(mixed, "seller-b"), false);
    assert.equal(sellerOwnsEntireOrder({ lines: [] }, "seller-a"), false);

    assert.deepEqual(sellerOrderMutationAccess(own, "seller-a"), { ok: true });

    const mixedOwnLine = sellerOrderMutationAccess(mixed, "seller-a");
    assert.equal(mixedOwnLine.ok, false);
    if (!mixedOwnLine.ok) assert.equal(mixedOwnLine.status, 409);

    const stranger = sellerOrderMutationAccess(own, "seller-c");
    assert.equal(stranger.ok, false);
    if (!stranger.ok) assert.equal(stranger.status, 403);
  });

  it("splits a mixed cart into one bucket per seller", () => {
    const grouped = groupOrderLinesBySeller([
      line("seller-a", "p1", 40),
      line("seller-b", "p3", 80),
      line("seller-a", "p2", 20),
    ]);

    assert.equal(grouped.size, 2);
    assert.deepEqual(
      grouped.get("seller-a")?.map((l) => l.productId),
      ["p1", "p2"],
    );
    assert.deepEqual(
      grouped.get("seller-b")?.map((l) => l.productId),
      ["p3"],
    );
    assert.equal(subtotalForLines(grouped.get("seller-a") ?? []), 60);
    assert.equal(subtotalForLines(grouped.get("seller-b") ?? []), 80);
  });

  it("refuses lines with no seller so a store cannot inherit another shop's item", () => {
    assert.throws(
      () =>
        groupOrderLinesBySeller([
          { productId: "p1", sellerId: "seller-a" },
          { productId: "p2" },
        ]),
      /sellerId/,
    );
  });

  it("mints distinct order ids so a mixed checkout cannot collide", () => {
    const ids = new Set(Array.from({ length: 20 }, () => newOrderId()));
    assert.equal(ids.size, 20);
  });
});

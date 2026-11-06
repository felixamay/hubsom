import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { getEffectivePrice, isFlashSaleActive } from "../src/lib/pricing.ts";

const now = Date.parse("2026-11-06T12:00:00.000Z");

describe("isFlashSaleActive", () => {
  it("is false when there is no flash sale", () => {
    assert.equal(isFlashSaleActive(undefined, now), false);
  });

  it("is false after endsAt", () => {
    assert.equal(
      isFlashSaleActive(
        { endsAt: "2026-11-06T11:00:00.000Z", discountPct: 20 },
        now,
      ),
      false,
    );
  });

  it("is true before endsAt", () => {
    assert.equal(
      isFlashSaleActive(
        { endsAt: "2026-11-06T13:00:00.000Z", discountPct: 20 },
        now,
      ),
      true,
    );
  });
});

describe("getEffectivePrice", () => {
  it("applies an in-window flash sale", () => {
    assert.equal(
      getEffectivePrice(
        {
          priceGhs: 100,
          flashSale: { endsAt: "2026-11-06T13:00:00.000Z", discountPct: 20 },
        },
        now,
      ),
      80,
    );
  });

  it("charges the catalog price after the sale ends — checkout uses this", () => {
    assert.equal(
      getEffectivePrice(
        {
          priceGhs: 100,
          flashSale: { endsAt: "2026-11-06T11:00:00.000Z", discountPct: 20 },
        },
        now,
      ),
      100,
    );
  });

  it("ignores a sale with an unparseable end time", () => {
    assert.equal(
      getEffectivePrice(
        {
          priceGhs: 100,
          flashSale: { endsAt: "not-a-date", discountPct: 90 },
        },
        now,
      ),
      100,
    );
  });
});

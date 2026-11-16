import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { withFileLock } from "./persist.ts";

describe("withFileLock", () => {
  it("serializes concurrent read-modify-write so increments are not lost", async () => {
    let value = 0;
    await Promise.all(
      Array.from({ length: 40 }, () =>
        withFileLock("persist-test-counter", async () => {
          const current = value;
          await new Promise((r) => setTimeout(r, 1));
          value = current + 1;
        }),
      ),
    );
    assert.equal(value, 40);
  });
});

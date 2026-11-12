import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { after, before, describe, test } from "node:test";
import { readJsonFile, writeJsonFile } from "./persist.ts";

type Store = { orders: Array<{ id: string }> };

describe("persist json store", () => {
  let tmp = "";

  before(async () => {
    tmp = await mkdtemp(path.join(os.tmpdir(), "hubsom-persist-"));
    process.env.HUBSOM_DATA_DIR = tmp;
  });

  after(async () => {
    if (tmp) await rm(tmp, { recursive: true, force: true });
  });

  test("missing file bootstraps fallback without wiping later writes", async () => {
    const created = await readJsonFile<Store>("orders.json", { orders: [] });
    assert.deepEqual(created, { orders: [] });

    await writeJsonFile("orders.json", { orders: [{ id: "ord_paid" }] });
    const loaded = await readJsonFile<Store>("orders.json", { orders: [] });
    assert.equal(loaded.orders[0]?.id, "ord_paid");
  });

  test("atomic write leaves a complete JSON file", async () => {
    await writeJsonFile("products.json", {
      products: [{ id: "prod-1", name: "Shea" }],
    });
    const raw = await readFile(path.join(tmp, "products.json"), "utf8");
    const parsed = JSON.parse(raw) as { products: Array<{ id: string }> };
    assert.equal(parsed.products[0]?.id, "prod-1");
    assert.equal(raw.trim().endsWith("}"), true);
  });

  test("empty file after a truncated write bootstraps fallback", async () => {
    const file = path.join(tmp, "users.json");
    await writeFile(file, "", "utf8");
    const loaded = await readJsonFile<{ users: string[] }>("users.json", {
      users: [],
    });
    assert.deepEqual(loaded, { users: [] });
  });

  test("corrupt JSON does not overwrite paid orders with an empty store", async () => {
    const file = path.join(tmp, "shipments.json");
    const torn = '{"shipments":[{"id":"shp_live","orderIds":["ord_1"]';
    await writeFile(file, torn, "utf8");

    await assert.rejects(
      () => readJsonFile("shipments.json", { shipments: [] }),
      /Corrupt data file shipments\.json/,
    );

    const stillThere = await readFile(file, "utf8");
    assert.equal(stillThere, torn);
  });
});

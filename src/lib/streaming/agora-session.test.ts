import assert from "node:assert/strict";
import { describe, test } from "node:test";
import {
  dropRefIfOwned,
  takeSessionResource,
} from "./agora-session";

describe("agora session ownership", () => {
  test("dropRefIfOwned leaves a newer session's client on the shared ref", () => {
    const oldClient = { id: "attempt-1" };
    const newClient = { id: "attempt-2" };
    const ref = { current: newClient };

    dropRefIfOwned(ref, oldClient);

    assert.equal(ref.current, newClient);
  });

  test("dropRefIfOwned clears the ref when it still owns the instance", () => {
    const client = { id: "attempt-1" };
    const ref = { current: client };

    dropRefIfOwned(ref, client);

    assert.equal(ref.current, null);
  });

  test("takeSessionResource releases immediately if the effect already disposed", () => {
    const released: string[] = [];
    const track = { id: "cam" };
    const ref = { current: null as typeof track | null };

    const owned = takeSessionResource(true, track, ref, (value) => {
      released.push(value.id);
    });

    assert.equal(owned, null);
    assert.equal(ref.current, null);
    assert.deepEqual(released, ["cam"]);
  });

  test("takeSessionResource adopts the resource when the effect is still active", () => {
    const released: string[] = [];
    const client = { id: "live" };
    const ref = { current: null as typeof client | null };

    const owned = takeSessionResource(false, client, ref, (value) => {
      released.push(value.id);
    });

    assert.equal(owned, client);
    assert.equal(ref.current, client);
    assert.deepEqual(released, []);
  });

  test("async cleanup of attempt 1 does not leave attempt 2's client", async () => {
    const left: string[] = [];
    const attempt1 = { id: "1", leave() { left.push(this.id); } };
    const attempt2 = { id: "2", leave() { left.push(this.id); } };
    const ref = { current: attempt1 as typeof attempt1 | typeof attempt2 | null };

    const owned1 = attempt1;
    ref.current = attempt2;

    await Promise.resolve();
    owned1.leave();
    dropRefIfOwned(ref, owned1);

    assert.deepEqual(left, ["1"]);
    assert.equal(ref.current, attempt2);
  });
});

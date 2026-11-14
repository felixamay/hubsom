import assert from "node:assert/strict";
import { after, describe, it } from "node:test";
import {
  createEmailUser,
  getUserByEmail,
  upsertOAuthUser,
  verifyEmailPassword,
} from "./users";
import { readJsonFile, writeJsonFile } from "./persist";
import type { HubsomUser } from "@/types/auth";

const TEST_EMAIL = `oauth-squat-${Date.now()}@hubsom.test`;
const TEST_PASSWORD = "attacker-pass-1";

async function removeTestUser() {
  const store = await readJsonFile<{ users: HubsomUser[] }>("users.json", {
    users: [],
  });
  const next = store.users.filter((u) => u.email !== TEST_EMAIL);
  if (next.length !== store.users.length) {
    await writeJsonFile("users.json", { users: next });
  }
}

describe("upsertOAuthUser email squat", () => {
  after(async () => {
    await removeTestUser();
  });

  it("strips the squat password so Google login does not leave a backdoor", async () => {
    await createEmailUser({
      name: "Squatter",
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
    });

    const before = await verifyEmailPassword(TEST_EMAIL, TEST_PASSWORD);
    assert.ok(before, "password signup should authenticate before OAuth link");

    const linked = await upsertOAuthUser({
      email: TEST_EMAIL,
      name: "Real Owner",
      provider: "google",
      providerAccountId: "google-sub-victim",
    });

    assert.equal(linked.email, TEST_EMAIL);
    assert.equal(linked.emailVerified, true);
    assert.equal(linked.oauthIds.google, "google-sub-victim");
    assert.equal(linked.passwordHash, undefined);
    assert.equal(linked.sessionEpoch, 1);

    const after = await verifyEmailPassword(TEST_EMAIL, TEST_PASSWORD);
    assert.equal(after, null, "squat password must no longer sign in");

    const stored = await getUserByEmail(TEST_EMAIL);
    assert.equal(stored?.passwordHash, undefined);
    assert.equal(stored?.sessionEpoch, 1);

    const again = await upsertOAuthUser({
      email: TEST_EMAIL,
      name: "Real Owner",
      provider: "google",
      providerAccountId: "google-sub-victim",
    });
    assert.equal(again.sessionEpoch, 1, "re-login must not bump epoch again");
    assert.equal(again.passwordHash, undefined);
  });

  it("keeps the password when the credentials email is already verified", async () => {
    const email = `oauth-verified-${Date.now()}@hubsom.test`;
    await createEmailUser({
      name: "Owner",
      email,
      password: TEST_PASSWORD,
    });
    const store = await readJsonFile<{ users: HubsomUser[] }>("users.json", {
      users: [],
    });
    const idx = store.users.findIndex((u) => u.email === email);
    assert.ok(idx >= 0);
    store.users[idx] = { ...store.users[idx], emailVerified: true };
    await writeJsonFile("users.json", store);

    await upsertOAuthUser({
      email,
      name: "Owner",
      provider: "google",
      providerAccountId: "google-sub-owner",
    });

    const still = await verifyEmailPassword(email, TEST_PASSWORD);
    assert.ok(still, "verified credentials must still sign in with the password");
    assert.equal(still.sessionEpoch, undefined);
    assert.equal(still.oauthIds.google, "google-sub-owner");

    const leftover = await readJsonFile<{ users: HubsomUser[] }>("users.json", {
      users: [],
    });
    await writeJsonFile("users.json", {
      users: leftover.users.filter((u) => u.email !== email),
    });
  });
});

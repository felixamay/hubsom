import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { HubsomUser } from "../../types/auth";
import { applyOAuthLink } from "./oauth-link";

function credentialsUser(overrides: Partial<HubsomUser> = {}): HubsomUser {
  return {
    id: "user-attacker",
    email: "victim@gmail.com",
    name: "Attacker",
    passwordHash: "bcrypt-hash-from-attacker",
    role: "seller",
    followingSellerIds: [],
    savedProductIds: [],
    addresses: [],
    providers: ["credentials"],
    oauthIds: {},
    emailVerified: false,
    createdAt: "2026-01-01T00:00:00.000Z",
    updatedAt: "2026-01-01T00:00:00.000Z",
    ...overrides,
  };
}

describe("applyOAuthLink", () => {
  it("drops the password when Google claims a pre-registered email", () => {
    const linked = applyOAuthLink(
      credentialsUser(),
      {
        name: "Ama Victim",
        image: "https://example.com/ama.png",
        provider: "google",
        providerAccountId: "google-sub-1",
      },
      "2026-11-19T11:00:00.000Z",
    );

    assert.equal(linked.passwordHash, undefined);
    assert.equal(linked.email, "victim@gmail.com");
    assert.equal(linked.id, "user-attacker");
    assert.equal(linked.emailVerified, true);
    assert.deepEqual(linked.providers, ["credentials", "google"]);
    assert.equal(linked.oauthIds.google, "google-sub-1");
    assert.equal(linked.name, "Ama Victim");
    assert.equal(linked.image, "https://example.com/ama.png");
  });

  it("keeps the password stripped on later OAuth sign-ins of a poisoned account", () => {
    const alreadyLinked = credentialsUser({
      providers: ["credentials", "google"],
      oauthIds: { google: "google-sub-1" },
      emailVerified: true,
    });

    const linked = applyOAuthLink(
      alreadyLinked,
      {
        name: "Ama Victim",
        provider: "google",
        providerAccountId: "google-sub-1",
      },
      "2026-11-19T11:05:00.000Z",
    );

    assert.equal(linked.passwordHash, undefined);
    assert.equal(linked.oauthIds.google, "google-sub-1");
    assert.equal(linked.name, "Attacker");
  });
});

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  isUnverifiedPasswordSquat,
  nextSessionEpoch,
  sessionEpochRevoked,
} from "./oauth-link";

describe("isUnverifiedPasswordSquat", () => {
  it("detects an unverified password account linked only by email", () => {
    assert.equal(
      isUnverifiedPasswordSquat(
        {
          passwordHash: "bcrypt-hash",
          emailVerified: false,
          oauthIds: {},
        },
        "google",
      ),
      true,
    );
  });

  it("does not treat an already-linked Google user as a squat", () => {
    assert.equal(
      isUnverifiedPasswordSquat(
        {
          passwordHash: "bcrypt-hash",
          emailVerified: true,
          oauthIds: { google: "existing-google-id" },
        },
        "google",
      ),
      false,
    );
  });

  it("keeps a verified password so a real owner can still use email login", () => {
    assert.equal(
      isUnverifiedPasswordSquat(
        {
          passwordHash: "bcrypt-hash",
          emailVerified: true,
          oauthIds: {},
        },
        "google",
      ),
      false,
    );
  });

  it("ignores OAuth-only accounts with no password", () => {
    assert.equal(
      isUnverifiedPasswordSquat(
        { emailVerified: false, oauthIds: {} },
        "google",
      ),
      false,
    );
  });
});

describe("sessionEpochRevoked", () => {
  it("revokes a password session after OAuth takeover bumps the epoch", () => {
    assert.equal(sessionEpochRevoked(undefined, 1, false), true);
    assert.equal(sessionEpochRevoked(0, 1, false), true);
  });

  it("lets the new Google sign-in adopt the bumped epoch", () => {
    assert.equal(sessionEpochRevoked(undefined, 1, true), false);
  });

  it("keeps sessions that already match the current epoch", () => {
    assert.equal(sessionEpochRevoked(1, 1, false), false);
  });

  it("does not log everyone out when epoch is unset", () => {
    assert.equal(sessionEpochRevoked(undefined, undefined, false), false);
    assert.equal(sessionEpochRevoked(0, 0, false), false);
  });
});

describe("nextSessionEpoch", () => {
  it("starts at 1 and increments", () => {
    assert.equal(nextSessionEpoch(undefined), 1);
    assert.equal(nextSessionEpoch(1), 2);
  });
});

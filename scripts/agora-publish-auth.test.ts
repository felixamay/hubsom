import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  clampTokenExpireSeconds,
  MAX_TOKEN_EXPIRE_SECONDS,
  resolveAgoraUid,
  userCanPublishOnStream,
  wantsPublisherRole,
} from "../src/lib/agora-publish-auth.ts";

describe("wantsPublisherRole", () => {
  it("only treats the exact publisher role as a camera grant", () => {
    assert.equal(wantsPublisherRole("publisher"), true);
    assert.equal(wantsPublisherRole("subscriber"), false);
    assert.equal(wantsPublisherRole("PUBLISHER"), false);
    assert.equal(wantsPublisherRole("host"), false);
    assert.equal(wantsPublisherRole(undefined), false);
  });
});

describe("userCanPublishOnStream", () => {
  it("allows the storefront owner and matching sellerId", () => {
    assert.equal(
      userCanPublishOnStream({
        userId: "user-1",
        userSellerId: "seller-1",
        streamSellerId: "seller-1",
      }),
      true,
    );
    assert.equal(
      userCanPublishOnStream({
        userId: "user-1",
        streamSellerId: "seller-9",
        sellerOwnerUserId: "user-1",
      }),
      true,
    );
  });

  it("allows a user listed as a host on the show", () => {
    assert.equal(
      userCanPublishOnStream({
        userId: "cohost-2",
        userSellerId: "seller-other",
        streamSellerId: "seller-1",
        sellerOwnerUserId: "user-1",
        hostUserIds: ["user-1", "cohost-2"],
      }),
      true,
    );
  });

  it("rejects a signed-in stranger", () => {
    assert.equal(
      userCanPublishOnStream({
        userId: "attacker",
        userSellerId: "seller-attacker",
        streamSellerId: "seller-victim",
        sellerOwnerUserId: "user-victim",
        hostUserIds: ["user-victim"],
      }),
      false,
    );
  });

  it("rejects anonymous callers", () => {
    assert.equal(
      userCanPublishOnStream({
        userId: "",
        streamSellerId: "seller-1",
        sellerOwnerUserId: "user-1",
      }),
      false,
    );
  });
});

describe("clampTokenExpireSeconds", () => {
  it("defaults to one hour and caps runaway expiries", () => {
    assert.equal(clampTokenExpireSeconds(undefined), 3600);
    assert.equal(clampTokenExpireSeconds(30), 60);
    assert.equal(clampTokenExpireSeconds(999999999), MAX_TOKEN_EXPIRE_SECONDS);
    assert.equal(clampTokenExpireSeconds("nope"), 3600);
  });
});

describe("resolveAgoraUid", () => {
  it("lets a host keep uid 1 for reconnects", () => {
    assert.equal(
      resolveAgoraUid({ requestedUid: 1, isPublisher: true }),
      1,
    );
  });

  it("ignores a viewer asking for the host uid", () => {
    const uid = resolveAgoraUid({ requestedUid: 1, isPublisher: false });
    assert.notEqual(uid, 0);
    assert.notEqual(uid, 1);
    assert.ok(uid >= 2);
  });
});

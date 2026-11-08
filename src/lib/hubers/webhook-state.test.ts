import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { DeliveryOffer, Shipment } from "../../types/orders";
import {
  applyHubersWebhook,
  matchOffer,
  unsignedWebhooksAllowed,
} from "./webhook-state.ts";

function offer(partial: Partial<DeliveryOffer> & Pick<DeliveryOffer, "id">): DeliveryOffer {
  return {
    shipmentId: "shp_live",
    huberId: "huber-ama",
    huberName: "Ama Rider",
    status: "sent",
    createdAt: "2026-11-08T10:00:00.000Z",
    expiresAt: "2026-11-08T10:15:00.000Z",
    ...partial,
  };
}

function shipment(partial: Partial<Shipment> = {}): Shipment {
  return {
    id: "shp_live",
    sellerId: "seller-ama",
    createdByUserId: "user-ama",
    orderIds: ["ord_paid"],
    items: [
      {
        orderId: "ord_paid",
        productId: "prod-1",
        name: "Live bag",
        quantity: 1,
        lineTotalGhs: 80,
      },
    ],
    destination: {
      recipientName: "Kojo",
      phone: "0240000000",
      line1: "12 Ring Road",
      city: "Accra",
      region: "Greater Accra",
    },
    status: "offering",
    offers: [
      offer({ id: "off_ama", huberId: "huber-ama", huberName: "Ama Rider" }),
      offer({
        id: "off_kofi",
        huberId: "huber-kofi",
        huberName: "Kofi Rider",
      }),
    ],
    createdAt: "2026-11-08T10:00:00.000Z",
    updatedAt: "2026-11-08T10:00:00.000Z",
    ...partial,
  };
}

describe("applyHubersWebhook offer.accepted", () => {
  it("assigns the matching rider and declines the other open offers", () => {
    const next = applyHubersWebhook(shipment(), {
      event: "offer.accepted",
      offerId: "off_ama",
      riderId: "huber-ama",
      riderName: "Ama Rider",
    });

    assert.equal(next.status, "assigned");
    assert.equal(next.assignedHuberId, "huber-ama");
    assert.equal(next.assignedHuberName, "Ama Rider");
    assert.equal(
      next.offers.find((o) => o.id === "off_ama")?.status,
      "accepted",
    );
    assert.equal(
      next.offers.find((o) => o.id === "off_kofi")?.status,
      "declined",
    );
  });

  it("rejects a body with no matching offer so a guessed shipment id cannot take the job", () => {
    assert.throws(
      () =>
        applyHubersWebhook(shipment(), {
          event: "offer.accepted",
          riderId: "huber-attacker",
          riderName: "Attacker",
        }),
      /offerId or providerReference must match/,
    );
  });

  it("rejects a second rider after the lot is already assigned", () => {
    const assigned = applyHubersWebhook(shipment(), {
      event: "offer.accepted",
      offerId: "off_ama",
      riderId: "huber-ama",
    });

    assert.throws(
      () =>
        applyHubersWebhook(assigned, {
          event: "offer.accepted",
          offerId: "off_kofi",
          riderId: "huber-kofi",
        }),
      /already assigned to another rider/,
    );
  });

  it("is idempotent when the assigned rider's accept is retried", () => {
    const first = applyHubersWebhook(shipment(), {
      event: "offer.accepted",
      offerId: "off_ama",
      riderId: "huber-ama",
    });
    const retry = applyHubersWebhook(first, {
      event: "offer.accepted",
      offerId: "off_ama",
      riderId: "huber-ama",
    });

    assert.equal(retry.status, "assigned");
    assert.equal(retry.assignedHuberId, "huber-ama");
  });

  it("does not let offer.accepted rewind a delivered lot", () => {
    assert.throws(
      () =>
        applyHubersWebhook(
          shipment({
            status: "delivered",
            assignedHuberId: "huber-ama",
            assignedHuberName: "Ama Rider",
          }),
          { event: "offer.accepted", offerId: "off_ama", riderId: "huber-kofi" },
        ),
      /is delivered and cannot be assigned/,
    );
  });
});

describe("applyHubersWebhook delivery events", () => {
  it("does not cancel a delivered lot so the paid order cannot go out again", () => {
    assert.throws(
      () =>
        applyHubersWebhook(
          shipment({
            status: "delivered",
            assignedHuberId: "huber-ama",
          }),
          { event: "delivery.cancelled", reason: "retry" },
        ),
      /already delivered/,
    );
  });

  it("treats a duplicate delivered webhook as a no-op", () => {
    const current = shipment({
      status: "delivered",
      assignedHuberId: "huber-ama",
    });
    const next = applyHubersWebhook(current, { event: "delivery.delivered" });
    assert.equal(next.status, "delivered");
    assert.equal(next, current);
  });

  it("requires assignment before a pickup or drop-off event", () => {
    assert.throws(
      () =>
        applyHubersWebhook(shipment({ status: "offering" }), {
          event: "delivery.delivered",
        }),
      /must be assigned/,
    );
  });
});

describe("matchOffer", () => {
  it("does not match when neither offer id nor provider reference is sent", () => {
    assert.equal(
      matchOffer(shipment().offers, { riderId: "huber-ama" } as never),
      undefined,
    );
  });
});

describe("unsignedWebhooksAllowed", () => {
  it("blocks unsigned webhooks in production when no secret is configured", () => {
    assert.equal(unsignedWebhooksAllowed("production", undefined), false);
    assert.equal(unsignedWebhooksAllowed("production", ""), false);
  });

  it("allows unsigned webhooks only outside production for early Huber connect", () => {
    assert.equal(unsignedWebhooksAllowed("development", undefined), true);
    assert.equal(unsignedWebhooksAllowed("development", "secret"), false);
  });
});

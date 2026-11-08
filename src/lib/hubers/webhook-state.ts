import type {
  DeliveryOffer,
  Shipment,
  ShipmentStatus,
} from "../../types/orders";

export type HubersWebhookEvent =
  | "offer.accepted"
  | "offer.declined"
  | "offer.expired"
  | "delivery.picked_up"
  | "delivery.out_for_delivery"
  | "delivery.delivered"
  | "delivery.cancelled";

export type HubersWebhookBody = {
  event?: HubersWebhookEvent;
  shipmentId?: string;
  offerId?: string;
  providerReference?: string;
  riderId?: string;
  riderName?: string;
  reason?: string;
};

const TERMINAL: ReadonlySet<ShipmentStatus> = new Set([
  "delivered",
  "cancelled",
]);

export function matchOffer(
  offers: DeliveryOffer[],
  body: Pick<HubersWebhookBody, "offerId" | "providerReference">,
): DeliveryOffer | undefined {
  const offerId = body.offerId?.trim();
  const providerReference = body.providerReference?.trim();
  if (!offerId && !providerReference) return undefined;
  return offers.find(
    (o) =>
      (offerId && o.id === offerId) ||
      (providerReference && o.providerReference === providerReference),
  );
}

function assertNotTerminal(shipment: Shipment, action: string) {
  if (TERMINAL.has(shipment.status)) {
    throw new Error(
      `Shipment ${shipment.id} is ${shipment.status} and cannot ${action}`,
    );
  }
}

function applyOfferAccepted(
  shipment: Shipment,
  body: HubersWebhookBody,
): Shipment {
  assertNotTerminal(shipment, "be assigned");
  if (shipment.status === "out_for_delivery") {
    throw new Error(
      `Shipment ${shipment.id} is already out for delivery`,
    );
  }

  const offer = matchOffer(shipment.offers, body);
  if (!offer) {
    throw new Error(
      "offerId or providerReference must match an offer on this shipment",
    );
  }

  const riderId = body.riderId?.trim() || offer.huberId;
  if (!riderId) {
    throw new Error("riderId is required to accept an offer");
  }
  if (shipment.assignedHuberId && shipment.assignedHuberId !== riderId) {
    throw new Error(
      `Shipment ${shipment.id} is already assigned to another rider`,
    );
  }
  if (
    offer.status !== "sent" &&
    offer.status !== "queued" &&
    offer.status !== "accepted"
  ) {
    throw new Error(`Offer ${offer.id} is ${offer.status} and cannot be accepted`);
  }

  const riderName = body.riderName?.trim() || offer.huberName;
  const offers = shipment.offers.map((o) => {
    if (o.id === offer.id) {
      return {
        ...o,
        status: "accepted" as const,
        providerReference: body.providerReference ?? o.providerReference,
      };
    }
    if (o.status === "sent" || o.status === "queued") {
      return { ...o, status: "declined" as const };
    }
    return o;
  });

  return {
    ...shipment,
    offers,
    status: "assigned",
    assignedHuberId: riderId,
    assignedHuberName: riderName,
  };
}

function applyOfferClosed(
  shipment: Shipment,
  body: HubersWebhookBody,
  nextStatus: "declined" | "expired",
): Shipment {
  const offer = matchOffer(shipment.offers, body);
  if (!offer) {
    throw new Error(
      "offerId or providerReference must match an offer on this shipment",
    );
  }
  if (offer.status === "accepted") {
    throw new Error(`Offer ${offer.id} was already accepted`);
  }
  return {
    ...shipment,
    offers: shipment.offers.map((o) =>
      o.id === offer.id ? { ...o, status: nextStatus } : o,
    ),
  };
}

const DELIVERY_STATUS: Record<
  Extract<
    HubersWebhookEvent,
    | "delivery.picked_up"
    | "delivery.out_for_delivery"
    | "delivery.delivered"
    | "delivery.cancelled"
  >,
  ShipmentStatus
> = {
  "delivery.picked_up": "out_for_delivery",
  "delivery.out_for_delivery": "out_for_delivery",
  "delivery.delivered": "delivered",
  "delivery.cancelled": "cancelled",
};

function applyDeliveryEvent(
  shipment: Shipment,
  event: keyof typeof DELIVERY_STATUS,
  reason?: string,
): Shipment {
  const nextStatus = DELIVERY_STATUS[event];

  if (shipment.status === nextStatus) {
    return shipment;
  }

  if (shipment.status === "delivered") {
    throw new Error(
      `Shipment ${shipment.id} is already delivered and cannot be ${nextStatus}`,
    );
  }

  if (event === "delivery.cancelled") {
    if (shipment.status === "cancelled") return shipment;
    return {
      ...shipment,
      status: "cancelled",
      notes: reason
        ? `${shipment.notes ? `${shipment.notes}\n` : ""}${reason}`
        : shipment.notes,
    };
  }

  if (shipment.status === "cancelled") {
    throw new Error(`Shipment ${shipment.id} is cancelled`);
  }

  if (
    event === "delivery.picked_up" ||
    event === "delivery.out_for_delivery" ||
    event === "delivery.delivered"
  ) {
    if (shipment.status !== "assigned" && shipment.status !== "out_for_delivery") {
      throw new Error(
        `Shipment ${shipment.id} must be assigned before ${event}`,
      );
    }
  }

  return {
    ...shipment,
    status: nextStatus,
    notes: reason
      ? `${shipment.notes ? `${shipment.notes}\n` : ""}${reason}`
      : shipment.notes,
  };
}

/** Apply a Huber webhook to a shipment. Throws on illegal transitions. */
export function applyHubersWebhook(
  shipment: Shipment,
  body: HubersWebhookBody,
): Shipment {
  switch (body.event) {
    case "offer.accepted":
      return applyOfferAccepted(shipment, body);
    case "offer.declined":
      return applyOfferClosed(shipment, body, "declined");
    case "offer.expired":
      return applyOfferClosed(shipment, body, "expired");
    case "delivery.picked_up":
    case "delivery.out_for_delivery":
    case "delivery.delivered":
    case "delivery.cancelled":
      return applyDeliveryEvent(shipment, body.event, body.reason);
    default:
      throw new Error("Unknown event");
  }
}

export function unsignedWebhooksAllowed(
  nodeEnv: string | undefined,
  secret: string | undefined,
): boolean {
  if (secret) return false;
  return nodeEnv !== "production";
}

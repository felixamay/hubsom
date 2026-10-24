import { createHmac, timingSafeEqual } from "crypto";
import { NextResponse } from "next/server";
import {
  getShipment,
  updateShipmentDestination,
  type DeliveryOffer,
} from "@/lib/data/shipments";
import { readJsonFile, writeJsonFile } from "@/lib/data/persist";
import type { Shipment, ShipmentStatus } from "@/types/orders";

type HubersWebhookEvent =
  | "offer.accepted"
  | "offer.declined"
  | "offer.expired"
  | "delivery.picked_up"
  | "delivery.out_for_delivery"
  | "delivery.delivered"
  | "delivery.cancelled";

type WebhookBody = {
  source?: string;
  event?: HubersWebhookEvent;
  shipmentId?: string;
  offerId?: string;
  providerReference?: string;
  riderId?: string;
  riderName?: string;
  reason?: string;
  occurredAt?: string;
};

function verifySignature(rawBody: string, signatureHeader: string | null) {
  const secret = process.env.HUBERS_WEBHOOK_SECRET;
  if (!secret) {
    // Dev / pre-connect: allow unsigned webhooks so Huber can integrate early.
    return true;
  }
  if (!signatureHeader?.startsWith("sha256=")) return false;
  const expected = createHmac("sha256", secret).update(rawBody).digest("hex");
  const provided = signatureHeader.slice("sha256=".length);
  try {
    const a = Buffer.from(expected, "hex");
    const b = Buffer.from(provided, "hex");
    return a.length === b.length && timingSafeEqual(a, b);
  } catch {
    return false;
  }
}

async function patchShipmentOffers(
  shipmentId: string,
  mutate: (shipment: Shipment) => Shipment,
): Promise<Shipment | undefined> {
  const FILE = "shipments.json";
  type Store = { shipments: Shipment[] };
  const store = await readJsonFile<Store>(FILE, { shipments: [] });
  const idx = store.shipments.findIndex((s) => s.id === shipmentId);
  if (idx < 0) return undefined;
  store.shipments[idx] = mutate({
    ...store.shipments[idx],
    updatedAt: new Date().toISOString(),
  });
  await writeJsonFile(FILE, store);
  return store.shipments[idx];
}

function matchOffer(
  offers: DeliveryOffer[],
  body: WebhookBody,
): DeliveryOffer | undefined {
  return offers.find(
    (o) =>
      (body.offerId && o.id === body.offerId) ||
      (body.providerReference && o.providerReference === body.providerReference),
  );
}

export async function POST(request: Request) {
  const rawBody = await request.text();
  const signature = request.headers.get("x-hubers-signature");
  if (!verifySignature(rawBody, signature)) {
    return NextResponse.json({ error: "Invalid signature" }, { status: 401 });
  }

  let body: WebhookBody;
  try {
    body = JSON.parse(rawBody) as WebhookBody;
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  if (!body.shipmentId || !body.event) {
    return NextResponse.json(
      { error: "shipmentId and event required" },
      { status: 400 },
    );
  }

  const existing = await getShipment(body.shipmentId);
  if (!existing) {
    return NextResponse.json({ error: "Shipment not found" }, { status: 404 });
  }

  try {
    switch (body.event) {
      case "offer.accepted": {
        const shipment = await patchShipmentOffers(body.shipmentId, (s) => {
          const offer = matchOffer(s.offers, body);
          const offers = s.offers.map((o) => {
            if (offer && o.id === offer.id) {
              return {
                ...o,
                status: "accepted" as const,
                providerReference:
                  body.providerReference ?? o.providerReference,
              };
            }
            if (offer && o.status === "sent") {
              return { ...o, status: "declined" as const };
            }
            return o;
          });
          return {
            ...s,
            offers,
            status: "assigned",
            assignedHuberId: body.riderId ?? offer?.huberId,
            assignedHuberName: body.riderName ?? offer?.huberName,
          };
        });
        return NextResponse.json({ ok: true, shipment });
      }
      case "offer.declined":
      case "offer.expired": {
        const nextStatus =
          body.event === "offer.expired" ? "expired" : "declined";
        const shipment = await patchShipmentOffers(body.shipmentId, (s) => ({
          ...s,
          offers: s.offers.map((o) =>
            matchOffer([o], body)
              ? { ...o, status: nextStatus as DeliveryOffer["status"] }
              : o,
          ),
        }));
        return NextResponse.json({ ok: true, shipment });
      }
      case "delivery.picked_up":
      case "delivery.out_for_delivery":
      case "delivery.delivered":
      case "delivery.cancelled": {
        const statusMap: Record<string, ShipmentStatus> = {
          "delivery.picked_up": "out_for_delivery",
          "delivery.out_for_delivery": "out_for_delivery",
          "delivery.delivered": "delivered",
          "delivery.cancelled": "cancelled",
        };
        const shipment = await updateShipmentDestination(body.shipmentId, {
          status: statusMap[body.event],
          notes: body.reason
            ? `${existing.notes ? `${existing.notes}\n` : ""}${body.reason}`
            : undefined,
        });
        return NextResponse.json({ ok: true, shipment });
      }
      default:
        return NextResponse.json({ error: "Unknown event" }, { status: 400 });
    }
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error ? error.message : "Webhook handling failed",
      },
      { status: 400 },
    );
  }
}

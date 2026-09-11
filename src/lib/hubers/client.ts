import { readJsonFile, writeJsonFile } from "@/lib/data/persist";
import type { GeoLocation } from "@/types/orders";
import {
  attachOffersToShipment,
  getShipment,
  type DeliveryOffer,
  type Shipment,
} from "@/lib/data/shipments";

const FILE = "hubers.json";

export type HuberApprovalStatus = "pending" | "approved" | "suspended";
export type HuberAvailability = "offline" | "available" | "busy";

export interface HuberRider {
  id: string;
  name: string;
  phone: string;
  city: string;
  region: string;
  approvalStatus: HuberApprovalStatus;
  availability: HuberAvailability;
  rating: number;
  vehicle?: string;
  lastLocation?: GeoLocation;
}

type Store = { hubers: HuberRider[] };

const SEED: HuberRider[] = [];

async function load(): Promise<Store> {
  return readJsonFile<Store>(FILE, { hubers: SEED });
}

export async function listApprovedAvailableHubers(): Promise<HuberRider[]> {
  const store = await load();
  return store.hubers.filter(
    (h) =>
      h.approvalStatus === "approved" &&
      (h.availability === "available" || h.availability === "busy"),
  );
}

export async function listApprovedHubers(): Promise<HuberRider[]> {
  const store = await load();
  return store.hubers.filter((h) => h.approvalStatus === "approved");
}

/**
 * Hubers app adapter.
 * Offers are persisted locally; when HUBERS_API_BASE_URL is set, Hubsom POSTs to Huber.
 */
export async function sendHubersDeliveryOffers(input: {
  shipment: Shipment;
  preferredFeeGhs?: number;
}): Promise<{
  shipment: Shipment;
  offers: DeliveryOffer[];
  integration: "pending" | "live";
  message: string;
}> {
  const shipment = await getShipment(input.shipment.id);
  if (!shipment) throw new Error("Shipment not found");
  if (shipment.status === "cancelled" || shipment.status === "delivered") {
    throw new Error("This shipment can’t accept new rider offers");
  }
  if (!shipment.destination.location) {
    throw new Error("Add the buyer location pin before sending to Hubers");
  }

  const apiBase = process.env.HUBERS_API_BASE_URL?.replace(/\/$/, "");
  const apiKey = process.env.HUBERS_API_KEY;
  const now = Date.now();
  const expiresAt = new Date(now + 15 * 60 * 1000).toISOString();

  if (apiBase) {
    const res = await fetch(`${apiBase}/v1/delivery-offers`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(apiKey ? { Authorization: `Bearer ${apiKey}` } : {}),
      },
      body: JSON.stringify({
        source: "hubsom",
        event: "delivery_offers.create",
        shipmentId: shipment.id,
        preferredFeeGhs: input.preferredFeeGhs,
        expiresAt,
        pickup: {
          label: "Hubsom seller pickup",
          sellerId: shipment.sellerId,
        },
        dropoff: shipment.destination,
        items: shipment.items,
        currency: "GHS",
      }),
    });
    const data = (await res.json().catch(() => ({}))) as {
      error?: string;
      offers?: Array<{
        huberOfferId?: string;
        riderId?: string;
        riderName?: string;
        status?: DeliveryOffer["status"];
        expiresAt?: string;
      }>;
    };
    if (!res.ok) {
      throw new Error(data.error ?? `Huber API error (${res.status})`);
    }
    const remoteOffers = data.offers ?? [];
    if (!remoteOffers.length) {
      throw new Error("Huber returned no rider offers");
    }
    const offers: DeliveryOffer[] = remoteOffers.map((offer, index) => ({
      id: `off_${now.toString(36)}_${index}`,
      shipmentId: shipment.id,
      huberId: offer.riderId || `huber-remote-${index}`,
      huberName: offer.riderName || "Huber rider",
      status: offer.status ?? "sent",
      offeredFeeGhs:
        typeof input.preferredFeeGhs === "number"
          ? Math.max(0, input.preferredFeeGhs)
          : undefined,
      providerReference: offer.huberOfferId,
      createdAt: new Date(now).toISOString(),
      expiresAt: offer.expiresAt ?? expiresAt,
    }));
    const updated = await attachOffersToShipment(shipment.id, offers);
    if (!updated) throw new Error("Could not attach Hubers offers");
    return {
      shipment: updated,
      offers,
      integration: "live",
      message: "Offers sent to Huber. Waiting for a rider to accept.",
    };
  }

  const riders = await listApprovedAvailableHubers();
  const available = riders.filter((r) => r.availability === "available");
  const targets = available.length ? available : riders;
  if (!targets.length) {
    throw new Error("No approved Hubers riders are available yet");
  }

  const offers: DeliveryOffer[] = targets.map((rider, index) => ({
    id: `off_${now.toString(36)}_${index}`,
    shipmentId: shipment.id,
    huberId: rider.id,
    huberName: rider.name,
    status: "sent",
    offeredFeeGhs:
      typeof input.preferredFeeGhs === "number"
        ? Math.max(0, input.preferredFeeGhs)
        : undefined,
    providerReference: `hubers-pending:${rider.id}:${shipment.id}`,
    createdAt: new Date(now).toISOString(),
    expiresAt,
  }));

  const updated = await attachOffersToShipment(shipment.id, offers);
  if (!updated) throw new Error("Could not attach Hubers offers");

  return {
    shipment: updated,
    offers,
    integration: "pending",
    message:
      "Offers queued locally. Set HUBERS_API_BASE_URL to connect the Huber app (see docs/HUBERS_INTEGRATION.md).",
  };
}

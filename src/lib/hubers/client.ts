import { readJsonFile, writeJsonFile } from "@/lib/data/persist";
import type { GeoLocation } from "@/lib/data/orders";
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

const SEED: HuberRider[] = [
  {
    id: "huber-ama",
    name: "Ama Mensah",
    phone: "0241001001",
    city: "Accra",
    region: "Greater Accra",
    approvalStatus: "approved",
    availability: "available",
    rating: 4.9,
    vehicle: "Motorbike",
    lastLocation: {
      latitude: 5.6037,
      longitude: -0.187,
      source: "gps",
      capturedAt: new Date().toISOString(),
    },
  },
  {
    id: "huber-kwesi",
    name: "Kwesi Boateng",
    phone: "0242002002",
    city: "Accra",
    region: "Greater Accra",
    approvalStatus: "approved",
    availability: "available",
    rating: 4.7,
    vehicle: "Motorbike",
  },
  {
    id: "huber-efua",
    name: "Efua Addo",
    phone: "0243003003",
    city: "Tema",
    region: "Greater Accra",
    approvalStatus: "approved",
    availability: "busy",
    rating: 4.8,
    vehicle: "Scooter",
  },
  {
    id: "huber-pending",
    name: "Pending Rider",
    phone: "0244004004",
    city: "Kumasi",
    region: "Ashanti",
    approvalStatus: "pending",
    availability: "offline",
    rating: 0,
  },
];

async function load(): Promise<Store> {
  const store = await readJsonFile<Store>(FILE, { hubers: [] });
  if (!store.hubers.length) {
    store.hubers = SEED;
    await writeJsonFile(FILE, store);
  }
  return store;
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
 * Hubers app adapter (stub).
 * Offers are persisted as queued/sent until the Hubers app webhook/API is connected.
 */
export async function sendHubersDeliveryOffers(input: {
  shipment: Shipment;
  preferredFeeGhs?: number;
}): Promise<{
  shipment: Shipment;
  offers: DeliveryOffer[];
  integration: "pending";
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

  const riders = await listApprovedAvailableHubers();
  const available = riders.filter((r) => r.availability === "available");
  const targets = available.length ? available : riders;
  if (!targets.length) {
    throw new Error("No approved Hubers riders are available yet");
  }

  const now = Date.now();
  const offers: DeliveryOffer[] = targets.map((rider, index) => ({
    id: `off_${now.toString(36)}_${index}`,
    shipmentId: shipment.id,
    huberId: rider.id,
    huberName: rider.name,
    // queued until Hubers app push/API is wired; marked sent for demo UX
    status: "sent",
    offeredFeeGhs:
      typeof input.preferredFeeGhs === "number"
        ? Math.max(0, input.preferredFeeGhs)
        : undefined,
    providerReference: `hubers-pending:${rider.id}:${shipment.id}`,
    createdAt: new Date(now).toISOString(),
    expiresAt: new Date(now + 15 * 60 * 1000).toISOString(),
  }));

  const updated = await attachOffersToShipment(shipment.id, offers);
  if (!updated) throw new Error("Could not attach Hubers offers");

  return {
    shipment: updated,
    offers,
    integration: "pending",
    message:
      "Offers sent to approved Hubers riders. Full Hubers app delivery sync is coming soon.",
  };
}

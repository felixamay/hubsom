import { readJsonFile, writeJsonFile } from "@/lib/data/persist";
import {
  getOrder,
  normalizeGeoLocation,
  normalizeShipping,
  type GeoLocation,
  type OrderShipping,
} from "@/lib/data/orders";

const FILE = "shipments.json";

export type ShipmentStatus =
  | "draft"
  | "ready"
  | "offering"
  | "assigned"
  | "out_for_delivery"
  | "delivered"
  | "cancelled";

export type DeliveryOfferStatus =
  | "queued"
  | "sent"
  | "accepted"
  | "declined"
  | "expired";

export interface ShipmentItem {
  orderId: string;
  productId: string;
  name: string;
  quantity: number;
  image?: string;
  lineTotalGhs: number;
}

export interface DeliveryOffer {
  id: string;
  shipmentId: string;
  huberId: string;
  huberName: string;
  status: DeliveryOfferStatus;
  offeredFeeGhs?: number;
  providerReference?: string;
  createdAt: string;
  expiresAt: string;
}

export interface Shipment {
  id: string;
  sellerId: string;
  createdByUserId: string;
  orderIds: string[];
  items: ShipmentItem[];
  destination: OrderShipping;
  status: ShipmentStatus;
  assignedHuberId?: string;
  assignedHuberName?: string;
  offers: DeliveryOffer[];
  notes?: string;
  createdAt: string;
  updatedAt: string;
}

type Store = { shipments: Shipment[] };

async function load(): Promise<Store> {
  return readJsonFile<Store>(FILE, { shipments: [] });
}

async function save(store: Store) {
  await writeJsonFile(FILE, store);
}

export async function listShipmentsBySeller(
  sellerId: string,
): Promise<Shipment[]> {
  const store = await load();
  return store.shipments.filter((s) => s.sellerId === sellerId);
}

export async function getShipment(
  shipmentId: string,
): Promise<Shipment | undefined> {
  const store = await load();
  return store.shipments.find((s) => s.id === shipmentId);
}

export async function createConsolidatedShipment(input: {
  sellerId: string;
  createdByUserId: string;
  orderIds: string[];
  destination?: Partial<OrderShipping>;
  notes?: string;
}): Promise<Shipment> {
  const orderIds = Array.from(new Set(input.orderIds.filter(Boolean)));
  if (orderIds.length < 1) {
    throw new Error("Select at least one purchase to ship");
  }

  const items: ShipmentItem[] = [];
  let destinationBase: OrderShipping | undefined;

  for (const orderId of orderIds) {
    const order = await getOrder(orderId);
    if (!order) throw new Error(`Order ${orderId} not found`);
    if (order.status === "cancelled") {
      throw new Error(`Order ${orderId} is cancelled`);
    }
    const myLines = order.lines.filter((l) => l.sellerId === input.sellerId);
    if (!myLines.length) {
      throw new Error(`Order ${orderId} has none of your products`);
    }
    for (const line of myLines) {
      items.push({
        orderId,
        productId: line.productId,
        name: line.name,
        quantity: line.quantity,
        image: line.image,
        lineTotalGhs: line.lineTotalGhs,
      });
    }
    if (!destinationBase && order.shipping) {
      destinationBase = order.shipping;
    }
  }

  if (!destinationBase && !input.destination) {
    throw new Error("Add a shipping destination before consolidating");
  }

  const destination = normalizeShipping({
    ...destinationBase,
    ...input.destination,
    location:
      input.destination?.location !== undefined
        ? input.destination.location
        : destinationBase?.location,
  });

  const now = new Date().toISOString();
  const shipment: Shipment = {
    id: `shp_${Date.now().toString(36)}`,
    sellerId: input.sellerId,
    createdByUserId: input.createdByUserId,
    orderIds,
    items,
    destination,
    status: destination.location ? "ready" : "draft",
    offers: [],
    notes: input.notes?.trim() || undefined,
    createdAt: now,
    updatedAt: now,
  };

  const store = await load();
  store.shipments.unshift(shipment);
  await save(store);
  return shipment;
}

export async function updateShipmentDestination(
  shipmentId: string,
  patch: {
    destination?: Partial<OrderShipping>;
    location?: Partial<GeoLocation> | null;
    notes?: string;
    status?: ShipmentStatus;
  },
): Promise<Shipment | undefined> {
  const store = await load();
  const idx = store.shipments.findIndex((s) => s.id === shipmentId);
  if (idx < 0) return undefined;

  const current = store.shipments[idx];
  let location = current.destination.location;
  if (patch.location === null) location = undefined;
  else if (patch.location !== undefined) {
    location = normalizeGeoLocation(patch.location);
  } else if (patch.destination?.location !== undefined) {
    location = normalizeGeoLocation(patch.destination.location);
  }

  const destination = normalizeShipping({
    ...current.destination,
    ...patch.destination,
    location,
  });

  let status = patch.status ?? current.status;
  if (!patch.status) {
    if (destination.location && status === "draft") status = "ready";
    if (!destination.location && status === "ready") status = "draft";
  }

  store.shipments[idx] = {
    ...current,
    destination,
    notes:
      patch.notes !== undefined
        ? patch.notes.trim() || undefined
        : current.notes,
    status,
    updatedAt: new Date().toISOString(),
  };
  await save(store);
  return store.shipments[idx];
}

export async function attachOffersToShipment(
  shipmentId: string,
  offers: DeliveryOffer[],
): Promise<Shipment | undefined> {
  const store = await load();
  const idx = store.shipments.findIndex((s) => s.id === shipmentId);
  if (idx < 0) return undefined;
  const current = store.shipments[idx];
  store.shipments[idx] = {
    ...current,
    offers: [...offers, ...current.offers],
    status: "offering",
    updatedAt: new Date().toISOString(),
  };
  await save(store);
  return store.shipments[idx];
}

/** Order ids already included in an active (non-cancelled/delivered) shipment. */
export async function listActiveShippedOrderIds(
  sellerId: string,
): Promise<Set<string>> {
  const shipments = await listShipmentsBySeller(sellerId);
  const ids = new Set<string>();
  for (const shipment of shipments) {
    if (shipment.status === "cancelled" || shipment.status === "delivered") {
      continue;
    }
    for (const orderId of shipment.orderIds) ids.add(orderId);
  }
  return ids;
}

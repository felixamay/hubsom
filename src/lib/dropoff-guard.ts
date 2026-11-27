import type { GeoLocation, ShipmentStatus } from "@/types/orders";

/** Once a rider has the job, rewriting drop-off silently reroutes them. */
export const DROPOFF_LOCKED_SHIPMENT_STATUSES: readonly ShipmentStatus[] = [
  "assigned",
  "out_for_delivery",
  "delivered",
  "cancelled",
];

export const SELLER_DEVICE_GPS_DROPOFF_ERROR =
  "Seller device GPS cannot be saved as the buyer drop-off. Enter the buyer's coordinates from the address, or keep the pin captured at checkout.";

export const DROPOFF_LOCKED_ERROR =
  "Drop-off is locked after a rider is assigned. Contact support to reroute.";

export function shipmentDropoffIsLocked(status: ShipmentStatus): boolean {
  return DROPOFF_LOCKED_SHIPMENT_STATUSES.includes(status);
}

export function assertNotSellerDeviceGpsPin(
  location: Partial<GeoLocation> | null | undefined,
): void {
  if (!location) return;
  if (location.source === "gps") {
    throw new Error(SELLER_DEVICE_GPS_DROPOFF_ERROR);
  }
}

export function assertShipmentDropoffMutable(
  status: ShipmentStatus,
  patch: { destination?: unknown; location?: unknown },
): void {
  if (!shipmentDropoffIsLocked(status)) return;
  if (patch.destination !== undefined || patch.location !== undefined) {
    throw new Error(DROPOFF_LOCKED_ERROR);
  }
}

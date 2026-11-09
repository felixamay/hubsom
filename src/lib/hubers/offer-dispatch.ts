import type { ShipmentStatus } from "@/types/orders";

/** Statuses where a rider already has (or had) the job. */
const BLOCK_NEW_OFFERS: ReadonlySet<string> = new Set([
  "assigned",
  "out_for_delivery",
  "delivered",
  "cancelled",
]);

export function shipmentCanAcceptNewOffers(
  status: ShipmentStatus | string,
): boolean {
  return !BLOCK_NEW_OFFERS.has(status);
}

/**
 * Sending Hubers offers on an assigned lot reset status to `offering`
 * and let a second rider take a job already in progress.
 */
export function assertShipmentCanAcceptNewOffers(
  status: ShipmentStatus | string,
): void {
  if (shipmentCanAcceptNewOffers(status)) return;
  if (status === "assigned" || status === "out_for_delivery") {
    throw new Error(
      "This shipment is already with a rider and cannot be re-offered",
    );
  }
  throw new Error("This shipment can’t accept new rider offers");
}

/** Cancelled lots free their orders; delivered and in-flight lots still occupy them. */
export function shipmentOccupiesOrders(status: string): boolean {
  return status !== "cancelled";
}

export function occupiedOrderIdsForSeller(
  shipments: Array<{
    sellerId: string;
    status: string;
    orderIds: string[];
  }>,
  sellerId: string,
): Set<string> {
  const ids = new Set<string>();
  for (const shipment of shipments) {
    if (shipment.sellerId !== sellerId) continue;
    if (!shipmentOccupiesOrders(shipment.status)) continue;
    for (const orderId of shipment.orderIds) {
      if (orderId) ids.add(orderId);
    }
  }
  return ids;
}

export function assertOrdersFreeToShip(
  orderIds: Iterable<string>,
  occupied: Set<string>,
): void {
  for (const orderId of orderIds) {
    if (occupied.has(orderId)) {
      throw new Error(`Order ${orderId} is already on a shipment`);
    }
  }
}

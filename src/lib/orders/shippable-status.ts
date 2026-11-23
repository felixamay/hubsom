/** Orders a seller may put on a Huber shipment. Checkout starts at pending_payment. */
export const SHIPPABLE_ORDER_STATUSES = ["paid", "processing"] as const;

export function isShippableOrderStatus(status: string): boolean {
  return status === "paid" || status === "processing";
}

export function unpaidShipmentError(orderId: string, status: string): string {
  const label = status.replaceAll("_", " ");
  return `Order ${orderId} is ${label}; mark it paid before shipping`;
}

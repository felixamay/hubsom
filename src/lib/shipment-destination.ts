import type { OrderShipping } from "@/types/orders";

/** Stable drop-off identity: recipient + phone + street, ignoring pin noise. */
export function shippingFingerprint(
  shipping?: OrderShipping | null,
): string {
  if (!shipping) return "";
  const name = shipping.recipientName.trim().toLowerCase();
  const phone = shipping.phone.replace(/\D/g, "");
  const line1 = shipping.line1.trim().toLowerCase();
  const city = shipping.city.trim().toLowerCase();
  const region = shipping.region.trim().toLowerCase();
  if (!name && !phone && !line1) return "";
  return `${name}|${phone}|${line1}|${city}|${region}`;
}

export function shipmentGroupKey(order: {
  id: string;
  shipping?: OrderShipping | null;
}): string {
  const fingerprint = shippingFingerprint(order.shipping);
  return fingerprint || `order:${order.id}`;
}

/** One Huber run has a single drop-off. Mixed buyers/addresses must not share it. */
export function assertSameDeliveryDestination(
  orders: Array<{ id: string; shipping?: OrderShipping | null }>,
): void {
  const keys = new Set(orders.map(shipmentGroupKey));
  if (keys.size > 1) {
    throw new Error(
      "Cannot pack orders for different buyers or addresses into one shipment",
    );
  }
}

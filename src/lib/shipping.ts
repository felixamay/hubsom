import type { GeoLocation, OrderShipping } from "@/types/orders";

export function normalizeGeoLocation(
  input: Partial<GeoLocation> | undefined | null,
): GeoLocation | undefined {
  if (!input) return undefined;
  const latitude = Number(input.latitude);
  const longitude = Number(input.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return undefined;
  }
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    throw new Error("Invalid map coordinates");
  }
  const accuracyM =
    typeof input.accuracyM === "number" && Number.isFinite(input.accuracyM)
      ? Math.max(0, input.accuracyM)
      : undefined;
  const source = input.source;
  return {
    latitude,
    longitude,
    accuracyM,
    source:
      source === "gps" ||
      source === "map-pin" ||
      source === "manual" ||
      source === "geocoded"
        ? source
        : "manual",
    capturedAt: input.capturedAt || new Date().toISOString(),
  };
}

export function normalizeShipping(
  input: Partial<OrderShipping> | undefined,
): OrderShipping {
  const recipientName = String(input?.recipientName ?? "").trim();
  const phone = String(input?.phone ?? "").trim();
  const line1 = String(input?.line1 ?? "").trim();
  const line2 = String(input?.line2 ?? "").trim() || undefined;
  const city = String(input?.city ?? "").trim() || "Accra";
  const region = String(input?.region ?? "").trim() || "Greater Accra";
  const notes = String(input?.notes ?? "").trim() || undefined;
  const label = String(input?.label ?? "").trim() || undefined;
  const location = normalizeGeoLocation(input?.location);

  if (!recipientName) throw new Error("Recipient name is required");
  if (!phone) throw new Error("Phone number is required for delivery");
  if (!line1) throw new Error("Shipping address is required");

  return {
    recipientName,
    phone,
    line1,
    line2,
    city,
    region,
    notes,
    label,
    location,
  };
}

export function mapsSearchUrl(shipping: OrderShipping): string {
  if (shipping.location) {
    const { latitude, longitude } = shipping.location;
    return `https://www.google.com/maps/search/?api=1&query=${latitude},${longitude}`;
  }
  const q = [
    shipping.line1,
    shipping.line2,
    shipping.city,
    shipping.region,
    "Ghana",
  ]
    .filter(Boolean)
    .join(", ");
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(q)}`;
}

export function formatShippingBlock(shipping: OrderShipping): string {
  return [
    shipping.recipientName,
    shipping.phone,
    shipping.line1,
    shipping.line2,
    `${shipping.city}, ${shipping.region}`,
    shipping.location
      ? `Pin: ${shipping.location.latitude.toFixed(5)}, ${shipping.location.longitude.toFixed(5)}`
      : null,
    shipping.notes ? `Note: ${shipping.notes}` : null,
  ]
    .filter(Boolean)
    .join("\n");
}

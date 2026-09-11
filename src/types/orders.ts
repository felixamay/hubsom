import type { ProductCategory } from "@/types";

export type OrderStatus =
  | "pending_payment"
  | "paid"
  | "fulfilled"
  | "cancelled";

export interface GeoLocation {
  latitude: number;
  longitude: number;
  accuracyM?: number;
  source?: "gps" | "map-pin" | "manual" | "geocoded";
  capturedAt?: string;
}

export interface OrderShipping {
  recipientName: string;
  phone: string;
  line1: string;
  line2?: string;
  city: string;
  region: string;
  notes?: string;
  label?: string;
  /** Buyer drop-off pin for riders / Locate */
  location?: GeoLocation;
}

export interface OrderLine {
  productId: string;
  sellerId?: string;
  name: string;
  image?: string;
  quantity: number;
  unitPriceGhs: number;
  lineTotalGhs: number;
  category: ProductCategory;
}

export interface Order {
  id: string;
  currency: "GHS";
  subtotalGhs: number;
  status: OrderStatus;
  userId?: string;
  buyerName?: string;
  buyerEmail?: string;
  streamId?: string;
  oneTap?: boolean;
  lines: OrderLine[];
  shipping?: OrderShipping;
  paymentMethods: string[];
  deliveryEstimate: string;
  createdAt: string;
}

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

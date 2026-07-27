"use client";

import Image from "next/image";
import { useRouter } from "next/navigation";
import { useMemo, useState, useTransition } from "react";
import {
  Bike,
  MapPin,
  Navigation,
  Package,
  Truck,
} from "lucide-react";
import { SellerOrderActions } from "@/components/seller/SellerOrderActions";
import { formatGhs } from "@/lib/currency";
import {
  mapsSearchUrl,
  type Order,
  type OrderShipping,
} from "@/lib/data/orders";
import type { Shipment } from "@/lib/data/shipments";
import { cn } from "@/lib/utils";

type OrderView = {
  order: Order;
  myLines: Order["lines"];
  myTotal: number;
  alreadyShipped: boolean;
};

export function SellerOrdersBoard({
  sellerId,
  orders,
  initialShipments,
  shippedOrderIds,
}: {
  sellerId: string;
  orders: Order[];
  initialShipments: Shipment[];
  shippedOrderIds: string[];
}) {
  const router = useRouter();
  const [selected, setSelected] = useState<string[]>([]);
  const [shipments, setShipments] = useState(initialShipments);
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const shipped = useMemo(() => new Set(shippedOrderIds), [shippedOrderIds]);

  const views: OrderView[] = useMemo(
    () =>
      orders.map((order) => {
        const myLines = order.lines.filter((l) => l.sellerId === sellerId);
        return {
          order,
          myLines,
          myTotal: myLines.reduce((sum, l) => sum + l.lineTotalGhs, 0),
          alreadyShipped: shipped.has(order.id),
        };
      }),
    [orders, sellerId, shipped],
  );

  function toggle(orderId: string) {
    setSelected((prev) =>
      prev.includes(orderId)
        ? prev.filter((id) => id !== orderId)
        : [...prev, orderId],
    );
  }

  function consolidate() {
    setError(null);
    setMessage(null);
    startTransition(async () => {
      try {
        const res = await fetch("/api/seller/shipments", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ orderIds: selected }),
        });
        const data = await res.json();
        if (!res.ok) {
          setError(data.error ?? "Could not consolidate purchases");
          return;
        }
        setShipments((prev) => [data.shipment as Shipment, ...prev]);
        setSelected([]);
        setMessage(
          "Shipment created. Add the buyer location pin, then Locate or send to Hubers.",
        );
        router.refresh();
      } catch {
        setError("Network error creating shipment");
      }
    });
  }

  return (
    <div className="space-y-8">
      <section className="rounded-3xl border border-hubsom-forest/10 bg-white/80 p-4">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.14em] text-hubsom-ink/45">
              Consolidate purchases
            </p>
            <p className="mt-1 text-sm text-hubsom-ink/65">
              Select paid/pending orders, create one shipment, pin the buyer
              location, then Locate or send offers to approved Hubers riders.
            </p>
          </div>
          <button
            type="button"
            disabled={pending || selected.length < 1}
            onClick={consolidate}
            className="rounded-xl bg-hubsom-forest px-3.5 py-2.5 text-xs font-bold text-white disabled:opacity-50"
          >
            {pending
              ? "Creating…"
              : `Create shipment${selected.length ? ` (${selected.length})` : ""}`}
          </button>
        </div>
        {message ? (
          <p className="mt-3 text-xs font-medium text-hubsom-leaf">{message}</p>
        ) : null}
        {error ? (
          <p className="mt-3 text-xs font-medium text-hubsom-live">{error}</p>
        ) : null}
      </section>

      {shipments.length ? (
        <section className="space-y-3">
          <h2 className="font-display text-xl font-bold text-hubsom-forest">
            Shipments
          </h2>
          {shipments.map((shipment) => (
            <ShipmentCard
              key={shipment.id}
              shipment={shipment}
              onUpdated={(next) => {
                setShipments((prev) =>
                  prev.map((s) => (s.id === next.id ? next : s)),
                );
                router.refresh();
              }}
            />
          ))}
        </section>
      ) : null}

      <section className="space-y-4">
        <h2 className="font-display text-xl font-bold text-hubsom-forest">
          Purchases
        </h2>
        {!views.length ? (
          <p className="rounded-2xl border border-dashed border-hubsom-forest/20 bg-white/50 px-4 py-8 text-center text-sm text-hubsom-ink/60">
            No orders yet.
          </p>
        ) : null}
        {views.map(({ order, myLines, myTotal, alreadyShipped }) => (
          <article
            key={order.id}
            className="overflow-hidden rounded-3xl border border-hubsom-forest/10 bg-white/80"
          >
            <div className="flex flex-wrap items-start justify-between gap-3 border-b border-hubsom-forest/8 px-4 py-3">
              <div className="flex items-start gap-3">
                <input
                  type="checkbox"
                  checked={selected.includes(order.id)}
                  disabled={
                    alreadyShipped ||
                    order.status === "cancelled" ||
                    order.status === "fulfilled"
                  }
                  onChange={() => toggle(order.id)}
                  className="mt-1.5 h-4 w-4 rounded border-hubsom-forest/30"
                  aria-label={`Select ${order.id}`}
                />
                <div>
                  <p className="font-display text-lg font-bold text-hubsom-forest">
                    {order.id}
                  </p>
                  <p className="text-xs text-hubsom-ink/55">
                    {new Date(order.createdAt).toLocaleString()} ·{" "}
                    {order.status.replace("_", " ")}
                    {order.oneTap ? " · live checkout" : ""}
                    {alreadyShipped ? " · in a shipment" : ""}
                  </p>
                </div>
              </div>
              <p className="font-display text-xl font-bold text-hubsom-ink">
                {formatGhs(myTotal)}
              </p>
            </div>

            <div className="space-y-3 px-4 py-4">
              <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wide text-hubsom-ink/45">
                <Package className="h-3.5 w-3.5" />
                Products
              </div>
              {myLines.map((line) => (
                <div
                  key={`${order.id}-${line.productId}`}
                  className="flex items-center gap-3 rounded-2xl bg-hubsom-mist/70 p-2.5"
                >
                  <div className="relative h-14 w-14 shrink-0 overflow-hidden rounded-xl bg-white">
                    {line.image ? (
                      <Image
                        src={line.image}
                        alt=""
                        fill
                        sizes="56px"
                        className="object-cover"
                      />
                    ) : (
                      <span className="flex h-full items-center justify-center text-[10px] font-bold text-hubsom-forest/40">
                        Item
                      </span>
                    )}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-bold text-hubsom-ink">
                      {line.name}
                    </p>
                    <p className="text-xs text-hubsom-ink/55">
                      Qty {line.quantity} · {line.category} ·{" "}
                      {formatGhs(line.unitPriceGhs)} each
                    </p>
                  </div>
                  <p className="shrink-0 text-sm font-bold text-hubsom-forest">
                    {formatGhs(line.lineTotalGhs)}
                  </p>
                </div>
              ))}

              <ShippingBlock
                orderId={order.id}
                shipping={order.shipping}
                buyerName={order.buyerName}
                buyerEmail={order.buyerEmail}
                onSaved={() => router.refresh()}
              />

              <SellerOrderActions
                orderId={order.id}
                status={order.status}
                buyerUserId={order.userId}
              />
            </div>
          </article>
        ))}
      </section>
    </div>
  );
}

function ShippingBlock({
  orderId,
  shipping,
  buyerName,
  buyerEmail,
  onSaved,
}: {
  orderId: string;
  shipping?: OrderShipping;
  buyerName?: string;
  buyerEmail?: string;
  onSaved: () => void;
}) {
  const [lat, setLat] = useState(
    shipping?.location?.latitude?.toString() ?? "",
  );
  const [lng, setLng] = useState(
    shipping?.location?.longitude?.toString() ?? "",
  );
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);

  function saveLocation(next?: { latitude: number; longitude: number }) {
    const latitude = next?.latitude ?? Number(lat);
    const longitude = next?.longitude ?? Number(lng);
    setError(null);
    setNote(null);
    startTransition(async () => {
      try {
        const res = await fetch(`/api/seller/orders/${orderId}`, {
          method: "PATCH",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            location: {
              latitude,
              longitude,
              source: next ? "gps" : "manual",
            },
          }),
        });
        const data = await res.json();
        if (!res.ok) {
          setError(data.error ?? "Could not save location");
          return;
        }
        setLat(String(latitude));
        setLng(String(longitude));
        setNote("Buyer location saved on this purchase");
        onSaved();
      } catch {
        setError("Network error");
      }
    });
  }

  function useDeviceLocation() {
    if (!navigator.geolocation) {
      setError("Location is not available in this browser");
      return;
    }
    setError(null);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        saveLocation({
          latitude: pos.coords.latitude,
          longitude: pos.coords.longitude,
        });
      },
      () => setError("Could not read current location"),
      { enableHighAccuracy: true, timeout: 12000 },
    );
  }

  return (
    <div className="rounded-2xl border border-dashed border-hubsom-forest/15 bg-hubsom-mist/40 p-3.5">
      <div className="mb-2 flex items-center gap-2 text-xs font-bold uppercase tracking-wide text-hubsom-ink/45">
        <Truck className="h-3.5 w-3.5" />
        Ship to
      </div>
      {shipping ? (
        <div className="space-y-0.5 text-sm text-hubsom-ink/80">
          <p className="font-semibold text-hubsom-ink">
            {shipping.recipientName}
          </p>
          <p>{shipping.phone}</p>
          <p>{shipping.line1}</p>
          {shipping.line2 ? <p>{shipping.line2}</p> : null}
          <p>
            {shipping.city}, {shipping.region}
          </p>
          {shipping.notes ? (
            <p className="pt-1 text-xs text-hubsom-ink/55">
              Note: {shipping.notes}
            </p>
          ) : null}
          {shipping.location ? (
            <p className="pt-1 text-xs font-medium text-hubsom-forest">
              Pin {shipping.location.latitude.toFixed(5)},{" "}
              {shipping.location.longitude.toFixed(5)}
            </p>
          ) : null}
        </div>
      ) : (
        <p className="text-sm text-hubsom-ink/55">
          No shipping on this older order.
        </p>
      )}
      {(buyerName || buyerEmail) && (
        <p className="mt-2 text-xs text-hubsom-ink/50">
          Buyer account: {buyerName}
          {buyerEmail ? ` · ${buyerEmail}` : ""}
        </p>
      )}

      {shipping ? (
        <div className="mt-3 space-y-2 border-t border-hubsom-forest/10 pt-3">
          <p className="text-[11px] font-semibold uppercase tracking-wide text-hubsom-ink/45">
            Buyer location for riders
          </p>
          <div className="grid grid-cols-2 gap-2">
            <input
              value={lat}
              onChange={(e) => setLat(e.target.value)}
              placeholder="Latitude"
              className="rounded-xl border border-hubsom-forest/12 bg-white px-3 py-2 text-xs outline-none focus:border-hubsom-gold"
            />
            <input
              value={lng}
              onChange={(e) => setLng(e.target.value)}
              placeholder="Longitude"
              className="rounded-xl border border-hubsom-forest/12 bg-white px-3 py-2 text-xs outline-none focus:border-hubsom-gold"
            />
          </div>
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              disabled={pending}
              onClick={() => saveLocation()}
              className="rounded-xl bg-hubsom-forest px-3 py-2 text-[11px] font-bold text-white disabled:opacity-50"
            >
              Save pin
            </button>
            <button
              type="button"
              disabled={pending}
              onClick={useDeviceLocation}
              className="inline-flex items-center gap-1 rounded-xl border border-hubsom-forest/15 bg-white px-3 py-2 text-[11px] font-bold text-hubsom-forest disabled:opacity-50"
            >
              <Navigation className="h-3.5 w-3.5" />
              Use GPS
            </button>
            <a
              href={mapsSearchUrl(shipping)}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-1 rounded-xl border border-hubsom-forest/15 bg-white px-3 py-2 text-[11px] font-bold text-hubsom-forest"
            >
              <MapPin className="h-3.5 w-3.5" />
              Locate
            </a>
          </div>
          {note ? (
            <p className="text-[11px] font-medium text-hubsom-leaf">{note}</p>
          ) : null}
          {error ? (
            <p className="text-[11px] font-medium text-hubsom-live">{error}</p>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

function ShipmentCard({
  shipment,
  onUpdated,
}: {
  shipment: Shipment;
  onUpdated: (shipment: Shipment) => void;
}) {
  const [lat, setLat] = useState(
    shipment.destination.location?.latitude?.toString() ?? "",
  );
  const [lng, setLng] = useState(
    shipment.destination.location?.longitude?.toString() ?? "",
  );
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);

  function savePin(next?: { latitude: number; longitude: number }) {
    const latitude = next?.latitude ?? Number(lat);
    const longitude = next?.longitude ?? Number(lng);
    setError(null);
    setNote(null);
    startTransition(async () => {
      try {
        const res = await fetch(`/api/seller/shipments/${shipment.id}`, {
          method: "PATCH",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            location: {
              latitude,
              longitude,
              source: next ? "gps" : "manual",
            },
          }),
        });
        const data = await res.json();
        if (!res.ok) {
          setError(data.error ?? "Could not save location");
          return;
        }
        setLat(String(latitude));
        setLng(String(longitude));
        setNote("Shipment destination pin saved");
        onUpdated(data.shipment as Shipment);
      } catch {
        setError("Network error");
      }
    });
  }

  function useDeviceLocation() {
    if (!navigator.geolocation) {
      setError("Location is not available in this browser");
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) =>
        savePin({
          latitude: pos.coords.latitude,
          longitude: pos.coords.longitude,
        }),
      () => setError("Could not read current location"),
      { enableHighAccuracy: true, timeout: 12000 },
    );
  }

  function sendToHubers() {
    setError(null);
    setNote(null);
    startTransition(async () => {
      try {
        const res = await fetch(
          `/api/seller/shipments/${shipment.id}/hubers`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({}),
          },
        );
        const data = await res.json();
        if (!res.ok) {
          setError(data.error ?? "Could not send to Hubers");
          return;
        }
        setNote(data.message ?? "Offers sent to approved Hubers riders");
        onUpdated(data.shipment as Shipment);
      } catch {
        setError("Network error contacting Hubers");
      }
    });
  }

  return (
    <article className="rounded-3xl border border-hubsom-gold/30 bg-gradient-to-br from-white to-hubsom-mist/80 p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="font-display text-lg font-bold text-hubsom-forest">
            {shipment.id}
          </p>
          <p className="text-xs text-hubsom-ink/55">
            {shipment.status.replaceAll("_", " ")} · {shipment.orderIds.length}{" "}
            purchase{shipment.orderIds.length === 1 ? "" : "s"} ·{" "}
            {shipment.items.length} item
            {shipment.items.length === 1 ? "" : "s"}
          </p>
        </div>
        <p className="text-sm font-bold text-hubsom-ink">
          {formatGhs(
            shipment.items.reduce((sum, item) => sum + item.lineTotalGhs, 0),
          )}
        </p>
      </div>

      <div className="mt-3 space-y-1.5">
        {shipment.items.map((item) => (
          <p
            key={`${item.orderId}-${item.productId}`}
            className="truncate text-xs text-hubsom-ink/70"
          >
            {item.name} × {item.quantity}{" "}
            <span className="text-hubsom-ink/40">({item.orderId})</span>
          </p>
        ))}
      </div>

      <div className="mt-3 rounded-2xl bg-white/80 p-3 text-sm text-hubsom-ink/80">
        <p className="font-semibold text-hubsom-ink">
          {shipment.destination.recipientName}
        </p>
        <p>{shipment.destination.phone}</p>
        <p>
          {shipment.destination.line1}
          {shipment.destination.line2 ? `, ${shipment.destination.line2}` : ""}
        </p>
        <p>
          {shipment.destination.city}, {shipment.destination.region}
        </p>
        {shipment.destination.location ? (
          <p className="mt-1 text-xs font-medium text-hubsom-forest">
            Pin {shipment.destination.location.latitude.toFixed(5)},{" "}
            {shipment.destination.location.longitude.toFixed(5)}
          </p>
        ) : (
          <p className="mt-1 text-xs text-hubsom-live">
            Add a location pin before sending to Hubers.
          </p>
        )}
      </div>

      <div className="mt-3 grid grid-cols-2 gap-2">
        <input
          value={lat}
          onChange={(e) => setLat(e.target.value)}
          placeholder="Latitude"
          className="rounded-xl border border-hubsom-forest/12 bg-white px-3 py-2 text-xs outline-none focus:border-hubsom-gold"
        />
        <input
          value={lng}
          onChange={(e) => setLng(e.target.value)}
          placeholder="Longitude"
          className="rounded-xl border border-hubsom-forest/12 bg-white px-3 py-2 text-xs outline-none focus:border-hubsom-gold"
        />
      </div>

      <div className="mt-3 flex flex-wrap gap-2">
        <button
          type="button"
          disabled={pending}
          onClick={() => savePin()}
          className="rounded-xl border border-hubsom-forest/15 bg-white px-3 py-2 text-[11px] font-bold text-hubsom-forest disabled:opacity-50"
        >
          Save pin
        </button>
        <button
          type="button"
          disabled={pending}
          onClick={useDeviceLocation}
          className="inline-flex items-center gap-1 rounded-xl border border-hubsom-forest/15 bg-white px-3 py-2 text-[11px] font-bold text-hubsom-forest disabled:opacity-50"
        >
          <Navigation className="h-3.5 w-3.5" />
          Use GPS
        </button>
        <a
          href={mapsSearchUrl(shipment.destination)}
          target="_blank"
          rel="noreferrer"
          className="inline-flex items-center gap-1 rounded-xl border border-hubsom-forest/15 bg-white px-3 py-2 text-[11px] font-bold text-hubsom-forest"
        >
          <MapPin className="h-3.5 w-3.5" />
          Locate
        </a>
        <button
          type="button"
          disabled={pending}
          onClick={sendToHubers}
          className={cn(
            "inline-flex items-center gap-1 rounded-xl px-3 py-2 text-[11px] font-bold text-hubsom-ink disabled:opacity-50",
            "bg-hubsom-gold",
          )}
        >
          <Bike className="h-3.5 w-3.5" />
          Hubers
        </button>
      </div>

      {shipment.offers.length ? (
        <div className="mt-3 space-y-1.5 rounded-2xl border border-hubsom-forest/10 bg-white/70 p-3">
          <p className="text-[11px] font-bold uppercase tracking-wide text-hubsom-ink/45">
            Rider offers
          </p>
          {shipment.offers.slice(0, 6).map((offer) => (
            <p key={offer.id} className="text-xs text-hubsom-ink/75">
              {offer.huberName} · {offer.status}
              {offer.providerReference ? (
                <span className="text-hubsom-ink/40">
                  {" "}
                  · {offer.providerReference.split(":")[0]}
                </span>
              ) : null}
            </p>
          ))}
          <p className="pt-1 text-[11px] text-hubsom-ink/50">
            Hubers app delivery sync is coming soon — offers are queued for
            approved riders.
          </p>
        </div>
      ) : null}

      {note ? (
        <p className="mt-2 text-[11px] font-medium text-hubsom-leaf">{note}</p>
      ) : null}
      {error ? (
        <p className="mt-2 text-[11px] font-medium text-hubsom-live">{error}</p>
      ) : null}
    </article>
  );
}

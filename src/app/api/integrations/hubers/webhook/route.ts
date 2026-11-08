import { createHmac, timingSafeEqual } from "crypto";
import { NextResponse } from "next/server";
import { getShipment } from "@/lib/data/shipments";
import { readJsonFile, writeJsonFile } from "@/lib/data/persist";
import {
  applyHubersWebhook,
  unsignedWebhooksAllowed,
  type HubersWebhookBody,
  type HubersWebhookEvent,
} from "@/lib/hubers/webhook-state";
import type { Shipment } from "@/types/orders";

type WebhookBody = HubersWebhookBody & {
  source?: string;
  event?: HubersWebhookEvent;
  occurredAt?: string;
};

function verifySignature(rawBody: string, signatureHeader: string | null) {
  const secret = process.env.HUBERS_WEBHOOK_SECRET;
  if (!secret) {
    // Dev / pre-connect only. Production must set HUBERS_WEBHOOK_SECRET so a
    // guessed shipment id cannot assign or cancel deliveries.
    return unsignedWebhooksAllowed(process.env.NODE_ENV, secret);
  }
  if (!signatureHeader?.startsWith("sha256=")) return false;
  const expected = createHmac("sha256", secret).update(rawBody).digest("hex");
  const provided = signatureHeader.slice("sha256=".length);
  try {
    const a = Buffer.from(expected, "hex");
    const b = Buffer.from(provided, "hex");
    return a.length === b.length && timingSafeEqual(a, b);
  } catch {
    return false;
  }
}

async function patchShipmentOffers(
  shipmentId: string,
  mutate: (shipment: Shipment) => Shipment,
): Promise<Shipment | undefined> {
  const FILE = "shipments.json";
  type Store = { shipments: Shipment[] };
  const store = await readJsonFile<Store>(FILE, { shipments: [] });
  const idx = store.shipments.findIndex((s) => s.id === shipmentId);
  if (idx < 0) return undefined;
  store.shipments[idx] = mutate({
    ...store.shipments[idx],
    updatedAt: new Date().toISOString(),
  });
  await writeJsonFile(FILE, store);
  return store.shipments[idx];
}

export async function POST(request: Request) {
  const rawBody = await request.text();
  const signature = request.headers.get("x-hubers-signature");
  if (!verifySignature(rawBody, signature)) {
    return NextResponse.json({ error: "Invalid signature" }, { status: 401 });
  }

  let body: WebhookBody;
  try {
    body = JSON.parse(rawBody) as WebhookBody;
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  if (!body.shipmentId || !body.event) {
    return NextResponse.json(
      { error: "shipmentId and event required" },
      { status: 400 },
    );
  }

  const existing = await getShipment(body.shipmentId);
  if (!existing) {
    return NextResponse.json({ error: "Shipment not found" }, { status: 404 });
  }

  try {
    const shipment = await patchShipmentOffers(body.shipmentId, (s) =>
      applyHubersWebhook(s, body),
    );
    return NextResponse.json({ ok: true, shipment });
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error ? error.message : "Webhook handling failed",
      },
      { status: 400 },
    );
  }
}

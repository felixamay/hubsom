import type { Metadata } from "next";
import Link from "next/link";
import {
  CreditCard,
  Heart,
  MapPin,
  Package,
  Settings,
  ShoppingBag,
  Store,
} from "lucide-react";
import { listOrders } from "@/lib/data/orders";
import { formatGhs } from "@/lib/currency";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Account",
};

const rows = [
  { href: "/cart", label: "Orders & cart", icon: ShoppingBag },
  { href: "/marketplace", label: "Browse stores", icon: Store },
  { href: "/flash-sales", label: "Saved deals", icon: Heart },
  { href: "/account", label: "Addresses", icon: MapPin },
  { href: "/account", label: "Payments (MoMo / Card)", icon: CreditCard },
  { href: "/account", label: "Settings", icon: Settings },
];

export default async function AccountPage() {
  const orders = await listOrders();

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
        Account
      </h1>

      <div className="mt-5 flex items-center gap-3 rounded-2xl border border-hubsom-forest/10 bg-white/80 p-4">
        <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-hubsom-cyan to-hubsom-blue font-display text-xl font-bold text-white">
          Y
        </div>
        <div>
          <p className="font-display text-xl font-bold text-hubsom-ink">Guest</p>
          <p className="text-sm text-hubsom-ink/60">
            Sign-in coming soon · browsing as guest
          </p>
        </div>
      </div>

      <div className="mt-5 overflow-hidden rounded-2xl border border-hubsom-forest/10 bg-white/80">
        {rows.map((row, i) => {
          const Icon = row.icon;
          return (
            <Link
              key={`${row.label}-${i}`}
              href={row.href}
              className="flex items-center gap-3 border-b border-hubsom-forest/8 px-4 py-3.5 last:border-b-0 active:bg-hubsom-mint/50"
            >
              <Icon className="h-5 w-5 text-hubsom-forest" />
              <span className="text-sm font-semibold text-hubsom-ink">
                {row.label}
              </span>
            </Link>
          );
        })}
      </div>

      <div className="mt-5">
        <div className="mb-3 flex items-center gap-2">
          <Package className="h-4 w-4 text-hubsom-forest" />
          <h2 className="font-display text-lg font-bold text-hubsom-ink">
            Recent orders
          </h2>
        </div>
        {!orders.length ? (
          <p className="rounded-2xl border border-dashed border-hubsom-forest/20 bg-white/50 px-4 py-8 text-center text-sm text-hubsom-ink/60">
            No orders yet.
          </p>
        ) : (
          <div className="space-y-2">
            {orders.slice(0, 8).map((order) => (
              <div
                key={order.id}
                className="rounded-2xl border border-hubsom-forest/10 bg-white/80 px-4 py-3"
              >
                <div className="flex items-center justify-between gap-2">
                  <p className="text-sm font-semibold text-hubsom-ink">
                    {order.id}
                  </p>
                  <p className="text-sm font-bold text-hubsom-forest">
                    {formatGhs(order.subtotalGhs)}
                  </p>
                </div>
                <p className="mt-1 text-xs text-hubsom-ink/55">
                  {order.status.replace("_", " ")} · {order.lines.length} items
                </p>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import {
  CreditCard,
  Heart,
  LogOut,
  MapPin,
  Package,
  Settings,
  ShoppingBag,
  Store,
  UserRound,
} from "lucide-react";
import { signOut } from "@/auth";
import { requireUser } from "@/lib/auth/session";
import { listOrdersByUser } from "@/lib/data/orders";
import { getUserById } from "@/lib/data/users";
import { formatGhs } from "@/lib/currency";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Account",
};

export default async function AccountPage() {
  const session = await requireUser("/account");

  const user = await getUserById(session.user.id);
  const orders = await listOrdersByUser(session.user.id);
  const initials = (user?.name || session.user.name || "U")
    .split(" ")
    .map((p) => p[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  const rows = [
    { href: "/account/profile", label: "Edit profile", icon: UserRound },
    { href: "/cart", label: "Orders & cart", icon: ShoppingBag },
    { href: "/account/addresses", label: "Addresses", icon: MapPin },
    { href: "/seller", label: "Seller hub", icon: Store },
    { href: "/flash-sales", label: "Saved deals", icon: Heart },
    { href: "/account/profile", label: "Payments (MoMo / Card)", icon: CreditCard },
    { href: "/account/profile", label: "Settings", icon: Settings },
  ];

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
        Account
      </h1>

      <div className="mt-5 flex items-center gap-3 rounded-2xl border border-hubsom-forest/10 bg-white/80 p-4">
        {user?.image ? (
          <Image
            src={user.image}
            alt={user.name}
            width={56}
            height={56}
            className="h-14 w-14 rounded-2xl object-cover"
          />
        ) : (
          <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-hubsom-cyan to-hubsom-blue font-display text-xl font-bold text-white">
            {initials}
          </div>
        )}
        <div className="min-w-0 flex-1">
          <p className="truncate font-display text-xl font-bold text-hubsom-ink">
            {user?.name ?? session.user.name}
          </p>
          <p className="truncate text-sm text-hubsom-ink/60">
            {user?.email ?? session.user.email}
          </p>
          <p className="mt-1 text-xs text-hubsom-ink/50">
            {[user?.city, user?.region].filter(Boolean).join(" · ") ||
              "Complete your profile"}
            {user?.role && user.role !== "buyer" ? ` · ${user.role}` : ""}
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

      <form
        action={async () => {
          "use server";
          await signOut({ redirectTo: "/auth/sign-in" });
        }}
        className="mt-4"
      >
        <button
          type="submit"
          className="flex w-full items-center justify-center gap-2 rounded-2xl border border-hubsom-forest/10 bg-white/80 px-4 py-3 text-sm font-semibold text-hubsom-live"
        >
          <LogOut className="h-4 w-4" />
          Sign out
        </button>
      </form>

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

import type { Metadata } from "next";
import Link from "next/link";
import {
  CreditCard,
  Heart,
  MapPin,
  Settings,
  ShoppingBag,
  Store,
} from "lucide-react";

export const metadata: Metadata = {
  title: "Account",
};

const rows = [
  { href: "/cart", label: "Orders & cart", icon: ShoppingBag },
  { href: "/stores/ama-market-live", label: "Following stores", icon: Store },
  { href: "/flash-sales", label: "Saved deals", icon: Heart },
  { href: "/account", label: "Addresses", icon: MapPin },
  { href: "/account", label: "Payments (MoMo / Card)", icon: CreditCard },
  { href: "/account", label: "Settings", icon: Settings },
];

export default function AccountPage() {
  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
        Account
      </h1>

      <div className="mt-5 flex items-center gap-3 rounded-2xl border border-hubsom-forest/10 bg-white/80 p-4">
        <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-hubsom-cyan to-hubsom-blue font-display text-xl font-bold text-white">
          FA
        </div>
        <div>
          <p className="font-display text-xl font-bold text-hubsom-ink">
            Felix Amesimeku
          </p>
          <p className="text-sm text-hubsom-ink/60">Accra · Hubsom member</p>
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
    </div>
  );
}
